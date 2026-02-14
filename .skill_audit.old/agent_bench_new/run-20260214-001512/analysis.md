# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 378 | メインワークフロー定義（Phase 0-6）、コンテキスト節約原則、使い方 |
| approach-catalog.md | 202 | 改善アプローチカタログ（S/C/N/M 4カテゴリ、推奨プロンプト構成） |
| scoring-rubric.md | 70 | 採点基準（検出判定○△×、スコア計算式、推奨判定基準、収束判定） |
| proven-techniques.md | 70 | エージェント横断の実証済み知見（効果テクニック、アンチパターン、条件付き、Phase 6B自動更新） |
| test-document-guide.md | 254 | テスト対象文書生成ガイド（入力型判定、基本構成、問題埋め込みルール、正解キー形式） |
| templates/knowledge-init-template.md | 53 | knowledge.md 初期化テンプレート（バリエーションステータステーブル生成） |
| templates/phase1a-variant-generation.md | 40 | 初回バリアント生成（ベースライン構築 + 構造ギャップ分析 + 2バリアント） |
| templates/phase1b-variant-generation.md | 36 | 継続バリアント生成（Broad/Deep モード選定 + audit findings 参照） |
| templates/phase2-test-document.md | 33 | テスト文書生成（入力型判定 + 問題埋め込み + 正解キー生成） |
| templates/phase4-scoring.md | 13 | 採点実行（Run1/Run2の検出判定 + ボーナス/ペナルティ） |
| templates/phase5-analysis-report.md | 24 | 比較レポート作成（推奨判定 + 収束判定 + 7行サマリ返答） |
| templates/phase6a-knowledge-update.md | 26 | knowledge.md更新（効果テーブル + バリエーションステータス + 一般化原則） |
| templates/phase6b-proven-techniques-update.md | 51 | proven-techniques.md更新（Tier 1-3昇格ルール + preserve+integrate統合） |
| templates/perspective/generate-perspective.md | 67 | パースペクティブ初期生成（必須スキーマ、入力型判定、問題バンク生成） |
| templates/perspective/critic-clarity.md | 76 | 批評：表現明確性・AI動作一貫性（曖昧表現検出 + 代替案提示） |
| templates/perspective/critic-effectiveness.md | 75 | 批評：有効性・境界明確性（寄与度分析 + 既存観点との重複検証） |
| templates/perspective/critic-generality.md | 107 | 批評：汎用性・業界独立性（3次元評価マトリクス + 抽象化戦略、英語） |
| templates/perspective/critic-completeness.md | 107 | 批評：網羅性・欠落検出能力（Essential Design Elements + Missing Element Detection、英語） |
| perspectives/code/best-practices.md | 34 | コードレビュー観点：SOLID、DRY、エラー処理、ロギング、テスト品質 |
| perspectives/code/consistency.md | 33 | コードレビュー観点：スタイル、命名規約、パターン統一 |
| perspectives/code/maintainability.md | 43 | コードレビュー観点：理解容易性、変更影響範囲、テスタビリティ、YAGNI |
| perspectives/code/security.md | 37 | コードレビュー観点：インジェクション、認証、機密データ、アクセス制御 |
| perspectives/code/performance.md | 37 | コードレビュー観点：クエリ効率、アルゴリズム、I/O、メモリ、キャッシュ |
| perspectives/design/consistency.md | 51 | 設計レビュー観点：命名規約、アーキテクチャ、実装パターン、ディレクトリ、API |
| perspectives/design/security.md | 43 | 設計レビュー観点：STRIDE脅威モデリング、認証認可、データ保護、入力検証、監査 |
| perspectives/design/structural-quality.md | 41 | 設計レビュー観点：SOLID、変更容易性、拡張性、エラーハンドリング、テスト設計、API |
| perspectives/design/performance.md | 45 | 設計レビュー観点：アルゴリズム、I/O、キャッシュ、レイテンシ、スケーラビリティ |
| perspectives/design/reliability.md | 43 | 設計レビュー観点：障害回復、データ整合性、可用性、監視、デプロイ |
| perspectives/design/old/best-practices.md | 34 | （旧）設計レビュー観点：ベストプラクティス |
| perspectives/design/old/maintainability.md | 43 | （旧）設計レビュー観点：保守性 |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → 1A/1B → 2 → 3 → 4 → 5 → 6
- 各フェーズの目的:
  - Phase 0: 初期化・perspective解決・agent_name導出・knowledge.md存在判定 → 1A/1B分岐
  - Phase 1A: 初回 — ベースライン構築 + 構造ギャップ分析 + 2バリアント生成（sonnet）
  - Phase 1B: 継続 — knowledge.md + audit findings参照 + Broad/Deep選定 + 2バリアント生成（sonnet）
  - Phase 2: テスト文書生成（入力型判定 + 問題埋め込み + 正解キー生成、sonnet）
  - Phase 3: 並列評価実行（プロンプト数 × 2回、sonnet）— 失敗時は再試行/除外/中断の3択
  - Phase 4: 採点（プロンプトごと並列、sonnet）— 失敗時は再試行/除外/中断の3択
  - Phase 5: 分析・推奨判定・レポート作成（sonnet）— 7行サマリ返答
  - Phase 6 Step 1: プロンプト選択・デプロイ（ユーザー選択、haiku）
  - Phase 6 Step 2A: knowledge.md更新（sonnet）
  - Phase 6 Step 2B: proven-techniques.md更新（sonnet）
  - Phase 6 Step 2C: 次アクション選択（親で実行）
- データフロー:
  - Phase 0 → perspective-source.md, perspective.md, knowledge.md（初期化時のみ）
  - Phase 1A/1B → prompts/v{NNN}-baseline.md, prompts/v{NNN}-variant-{name}.md
  - Phase 2 → test-document-round-{NNN}.md, answer-key-round-{NNN}.md
  - Phase 3 → results/v{NNN}-{name}-run{1|2}.md
  - Phase 4 → results/v{NNN}-{name}-scoring.md
  - Phase 5 → reports/round-{NNN}-comparison.md
  - Phase 6A → knowledge.md（更新）
  - Phase 6B → proven-techniques.md（更新）

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 54, 81, 92 | `.claude/skills/agent_bench_new/perspectives/{target}/{key}.md` | perspective フォールバック検索 |
| SKILL.md | 74 | `.claude/skills/agent_bench_new/perspectives/design/*.md` | 既存 perspective 参照データ収集 |
| SKILL.md | 81, 92 | `.claude/skills/agent_bench/templates/perspective/{テンプレート名}` | パースペクティブ自動生成（generate-perspective.md, critic-*.md） |
| SKILL.md | 130, 156, 177 | `.claude/skills/agent_bench/approach-catalog.md` | アプローチカタログ参照 |
| SKILL.md | 130, 135 | `.claude/skills/agent_bench/templates/knowledge-init-template.md` | knowledge.md 初期化 |
| SKILL.md | 152, 157, 178 | `.claude/skills/agent_bench/proven-techniques.md` | 実証済みテクニック参照 |
| SKILL.md | 152, 172, 192 | `.claude/skills/agent_bench/templates/phase1a-variant-generation.md` | Phase 1A テンプレート |
| SKILL.md | 172 | `.claude/skills/agent_bench/templates/phase1b-variant-generation.md` | Phase 1B テンプレート |
| SKILL.md | 192 | `.claude/skills/agent_bench/templates/phase2-test-document.md` | Phase 2 テンプレート |
| SKILL.md | 194 | `.claude/skills/agent_bench/test-document-guide.md` | テスト文書生成ガイド |
| SKILL.md | 257, 282 | `.claude/skills/agent_bench/templates/phase4-scoring.md` | Phase 4 テンプレート |
| SKILL.md | 259 | `.claude/skills/agent_bench/scoring-rubric.md` | 採点基準 |
| SKILL.md | 280, 282 | `.claude/skills/agent_bench/templates/phase5-analysis-report.md` | Phase 5 テンプレート |
| SKILL.md | 332, 340 | `.claude/skills/agent_bench/templates/phase6a-knowledge-update.md` | Phase 6A テンプレート |
| SKILL.md | 340, 344 | `.claude/skills/agent_bench/templates/phase6b-proven-techniques-update.md` | Phase 6B テンプレート |
| phase1b-variant-generation.md | 8 | `.agent_audit/{agent_name}/audit-*.md` | agent_audit 分析結果参照（除外: audit-approved.md） |

**注記**: SKILL.md では `.claude/skills/agent_bench/` と `.claude/skills/agent_bench_new/` の両方のパスが混在している。perspectives ディレクトリは `agent_bench_new` を参照し、templates は `agent_bench` を参照している。

## D. コンテキスト予算分析
- SKILL.md 行数: 378行
- テンプレートファイル数: 13個、平均行数: 48.7行
- サブエージェント委譲: あり（Phase 0〜6の全処理を委譲）
  - **委譲パターン**: 親（SKILL.md）はワークフロー制御のみ。全生成処理はサブエージェント（Task tool）に委譲
  - **返答形式**: サブエージェントは最小限のサマリのみ返答（詳細はファイルに保存）
  - **ファイル経由のデータ受け渡し**: サブエージェント間のデータ受け渡しはファイルパス指定で実施（親を中継しない）
- 親コンテキストに保持される情報:
  - agent_name, agent_path, perspective_source_path, 累計ラウンド数
  - バリエーションステータステーブル（knowledge.md から抽出）
  - 効果テーブル（knowledge.md から抽出）
  - サブエージェント返答（各Phase完了後のサマリのみ）
- 3ホップパターンの有無: **なし**（ファイル経由でデータ受け渡し）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時の確認 | 不明 |
| Phase 0 | AskUserQuestion | エージェント定義が不足時の要件ヒアリング | 不明 |
| Phase 3 | AskUserQuestion | 一部プロンプトで成功結果が0回の場合の再試行/除外/中断選択 | 不明 |
| Phase 4 | AskUserQuestion | 一部採点タスクが失敗した場合の再試行/除外/中断選択 | 不明 |
| Phase 6 Step 1 | AskUserQuestion | 推奨プロンプト選択（性能推移テーブル + 推奨理由を提示） | 不明 |
| Phase 6 Step 2C | AskUserQuestion | 次アクション選択（次ラウンド/終了） | 不明 |

**注記**: SKILL.md には fast mode への言及がないため、中間確認をスキップする機能は未実装と推測される。

## F. エラーハンドリングパターン
- ファイル不在時:
  - agent_path 読み込み失敗 → エラー出力して終了（Phase 0）
  - perspective-source.md 不在 → フォールバック検索 → 自動生成（Phase 0）
  - knowledge.md 不在 → 初期化して Phase 1A へ（Phase 0）
  - audit findings 不在 → 空文字列として処理継続（Phase 1B）
- サブエージェント失敗時:
  - Phase 3（並列評価）失敗 → AskUserQuestion で再試行/除外/中断の3択
  - Phase 4（採点）失敗 → AskUserQuestion で再試行/除外/中断の3択
  - Phase 5（分析レポート）失敗 → 未定義（SKILL.md に明示なし）
  - Phase 6A/6B（ナレッジ更新）失敗 → 未定義（SKILL.md に明示なし）
- 部分完了時:
  - Phase 3: 各プロンプトに最低1回の成功結果がある → 警告を出力し Phase 4 へ進む（SD=N/A）
  - Phase 4: ベースラインが失敗した場合は中断（他プロンプトのみ失敗時は除外可能）
- 入力バリデーション:
  - agent_path 未指定 → AskUserQuestion で確認（Phase 0）
  - perspective 検証失敗（必須セクション欠如）→ エラー出力してスキル終了（Phase 0）

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0（perspective生成 Step 3） | sonnet | templates/perspective/generate-perspective.md | 4行（観点・入力型・評価スコープ・問題バンク） | 1 |
| Phase 0（perspective批評 Step 4） | sonnet | templates/perspective/critic-effectiveness.md | 不定（SendMessage形式） | 4（並列） |
| Phase 0（perspective批評 Step 4） | sonnet | templates/perspective/critic-completeness.md | 不定（SendMessage形式） | 4（並列） |
| Phase 0（perspective批評 Step 4） | sonnet | templates/perspective/critic-clarity.md | 不定（SendMessage形式） | 4（並列） |
| Phase 0（perspective批評 Step 4） | sonnet | templates/perspective/critic-generality.md | 不定（SendMessage形式） | 4（並列） |
| Phase 0（perspective再生成 Step 5） | sonnet | templates/perspective/generate-perspective.md | 4行（再生成時） | 0-1（条件付） |
| Phase 0（knowledge初期化） | sonnet | templates/knowledge-init-template.md | 1行（初期化完了通知） | 0-1（初回のみ） |
| Phase 1A | sonnet | templates/phase1a-variant-generation.md | 35行（エージェント定義・構造分析・バリアント2件） | 1 |
| Phase 1B | sonnet | templates/phase1b-variant-generation.md | 19行（選定プロセス・バリアント2件） | 1 |
| Phase 2 | sonnet | templates/phase2-test-document.md | 18行（テスト文書サマリ・問題一覧・ボーナス一覧） | 1 |
| Phase 3 | sonnet | （テンプレートなし。プロンプト評価実行） | 1行（保存完了通知） | (プロンプト数 × 2回) 並列 |
| Phase 4 | sonnet | templates/phase4-scoring.md | 2行（スコアサマリ） | プロンプト数（並列） |
| Phase 5 | sonnet | templates/phase5-analysis-report.md | 7行（recommended, reason, convergence, scores, variants, deploy_info, user_summary） | 1 |
| Phase 6 Step 1（デプロイ） | haiku | （テンプレートなし。Benchmark Metadata除去 + 上書き） | 1行（デプロイ完了通知） | 0-1（ベースライン以外選択時） |
| Phase 6 Step 2A | sonnet | templates/phase6a-knowledge-update.md | 1行（更新完了通知） | 1 |
| Phase 6 Step 2B | sonnet | templates/phase6b-proven-techniques-update.md | 1行（更新結果通知） | 1 |

**並列実行の特徴**:
- Phase 0 Step 4: 4 critic エージェント並列
- Phase 3: 全プロンプト × 2回を同一メッセージ内で並列起動
- Phase 4: 全プロンプトの採点を並列起動
- Phase 6 Step 2: A（knowledge更新）と B（proven-techniques更新）と C（次アクション選択）を並列実行
