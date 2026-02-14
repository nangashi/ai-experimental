# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 397 | スキルメイン定義。ワークフロー全体（Phase 0-6）とパス変数、サブエージェント委譲パターンを記述 |
| approach-catalog.md | 202 | 改善アプローチカタログ。4カテゴリ（S/C/N/M）×テクニック×バリエーションの3階層構造。Phase 1A/1B で参照 |
| scoring-rubric.md | 70 | 採点基準定義。検出判定（○△×）、スコア計算式、推奨判定基準、収束判定。Phase 4/5 で参照 |
| proven-techniques.md | 70 | エージェント横断の実証済みテクニック。Phase 1A/1B/6B で参照/更新 |
| test-document-guide.md | 254 | テスト対象文書生成ガイド。入力型判定、文書構成、問題埋め込みガイドライン。Phase 2 で参照 |
| templates/knowledge-init-template.md | 53 | knowledge.md 初期化テンプレート。Phase 0（初回のみ）でサブエージェントが使用 |
| templates/phase1a-variant-generation.md | 41 | Phase 1A（初回）バリアント生成テンプレート。ベースライン構築 + 2バリアント生成 |
| templates/phase1b-variant-generation.md | 44 | Phase 1B（継続）バリアント生成テンプレート。Broad/Deep モード分岐、audit 結果参照 |
| templates/phase2-test-document.md | 32 | Phase 2 テスト文書生成テンプレート。入力型判定、問題埋め込み、正解キー生成 |
| templates/phase4-scoring.md | 13 | Phase 4 採点テンプレート。検出判定、ボーナス/ペナルティ、スコア計算 |
| templates/phase5-analysis-report.md | 23 | Phase 5 分析レポートテンプレート。推奨判定、収束判定、7行サマリ返答 |
| templates/phase6a-knowledge-update.md | 26 | Phase 6A knowledge.md 更新テンプレート。効果テーブル、バリエーションステータス、スコア推移更新 |
| templates/phase6b-proven-techniques-update.md | 53 | Phase 6B proven-techniques.md 更新テンプレート。Tier 1/2/3 昇格判定、統合ルール、サイズ制限 |
| templates/perspective/generate-perspective.md | 67 | perspective 自動生成テンプレート。必須スキーマ、入力型判定、問題バンク生成 |
| templates/perspective/critic-completeness.md | 107 | perspective 批評（網羅性）。欠落検出能力、問題バンク品質を評価 |
| templates/perspective/critic-clarity.md | 76 | perspective 批評（明確性）。表現の曖昧性、AI動作一貫性、実行可能性を評価 |
| templates/perspective/critic-effectiveness.md | 75 | perspective 批評（有効性）。品質寄与度、境界明確性を評価 |
| templates/perspective/critic-generality.md | 82 | perspective 批評（汎用性）。業界依存性、技術スタック依存性を評価 |
| perspectives/code/maintainability.md | 34 | 既存 perspective（コードレビュー/保守性）。Phase 0 のフォールバック参照用 |
| perspectives/code/security.md | 未読 | 既存 perspective（コードレビュー/セキュリティ）。Phase 0 のフォールバック参照用 |
| perspectives/code/performance.md | 未読 | 既存 perspective（コードレビュー/パフォーマンス）。Phase 0 のフォールバック参照用 |
| perspectives/code/best-practices.md | 未読 | 既存 perspective（コードレビュー/ベストプラクティス）。Phase 0 のフォールバック参照用 |
| perspectives/code/consistency.md | 未読 | 既存 perspective（コードレビュー/一貫性）。Phase 0 のフォールバック参照用 |
| perspectives/design/security.md | 43 | 既存 perspective（設計レビュー/セキュリティ）。Phase 0 のフォールバック参照用 |
| perspectives/design/consistency.md | 未読 | 既存 perspective（設計レビュー/一貫性）。Phase 0 のフォールバック参照用 |
| perspectives/design/structural-quality.md | 未読 | 既存 perspective（設計レビュー/構造品質）。Phase 0 のフォールバック参照用 |
| perspectives/design/performance.md | 未読 | 既存 perspective（設計レビュー/パフォーマンス）。Phase 0 のフォールバック参照用 |
| perspectives/design/reliability.md | 未読 | 既存 perspective（設計レビュー/信頼性）。Phase 0 のフォールバック参照用 |
| perspectives/design/old/maintainability.md | 未読 | 旧 perspective（設計レビュー/保守性）。現在未使用 |
| perspectives/design/old/best-practices.md | 未読 | 旧 perspective（設計レビュー/ベストプラクティス）。現在未使用 |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → (1A or 1B) → 2 → 3 → 4 → 5 → 6 → (1B へループ or 終了)
- 各フェーズの目的:
  - **Phase 0**: 初期化・agent_name 導出・perspective 解決（検索→フォールバック→自動生成）・knowledge.md 読み込み→初回/継続判定
  - **Phase 1A**: 初回ラウンド — ベースライン作成（proven-techniques ガイド適用）+ 2バリアント生成（構造ギャップ分析）
  - **Phase 1B**: 継続ラウンド — ベースラインコピー + 2バリアント生成（Broad/Deep モード、audit 結果参照可）
  - **Phase 2**: テスト入力文書 + 正解キー生成（入力型判定、問題埋め込み、ドメイン多様性確保）
  - **Phase 3**: 並列評価実行（各プロンプト × 2回実行、失敗時リトライ/除外/中断分岐）
  - **Phase 4**: 採点（問題別検出判定 ○△×、ボーナス/ペナルティ、Mean/SD 計算）
  - **Phase 5**: 分析レポート作成（推奨判定、収束判定、7行サマリ返答）
  - **Phase 6**: プロンプト選択・デプロイ（Step 1）→ knowledge.md 更新（Step 2A）+ proven-techniques.md 更新（Step 2B 並列）→ 次アクション選択（Step 3）
- データフロー:
  - **Phase 0 生成**: `.agent_bench/{agent_name}/perspective-source.md`, `perspective.md`, `knowledge.md`（初回のみ）
  - **Phase 1A/1B 生成**: `.agent_bench/{agent_name}/prompts/v{NNN}-*.md`
  - **Phase 2 生成**: `test-document-round-{NNN}.md`, `answer-key-round-{NNN}.md`
  - **Phase 3 生成**: `results/v{NNN}-{name}-run{1,2}.md`
  - **Phase 4 生成**: `results/v{NNN}-{name}-scoring.md`（Phase 5 で参照）
  - **Phase 5 生成**: `reports/round-{NNN}-comparison.md`（Phase 6A/6B で参照）
  - **Phase 6 更新**: `knowledge.md`（6A）、`proven-techniques.md`（6B）、`{agent_path}`（デプロイ）

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 30 | `.claude/skills/agent_bench_new/proven-techniques.md` | エージェント横断の実証済みテクニック（自動更新） |
| SKILL.md | 68 | `.claude/skills/agent_bench_new/perspectives/{target}/{key}.md` | perspective フォールバック検索パターン |
| SKILL.md | 93 | `.claude/skills/agent_bench_new/perspectives/design/*.md` | perspective 自動生成時の参照データ収集（構造参考用） |
| SKILL.md | 100 | `.claude/skills/agent_bench_new/templates/perspective/generate-perspective.md` | perspective 生成テンプレート |
| SKILL.md | 111 | `.claude/skills/agent_bench_new/templates/perspective/{critic-*.md}` | perspective 批評テンプレート（4並列） |
| SKILL.md | 145 | `.claude/skills/agent_bench_new/templates/knowledge-init-template.md` | knowledge.md 初期化テンプレート |
| SKILL.md | 148 | `.claude/skills/agent_bench_new/approach-catalog.md` | アプローチカタログ |
| SKILL.md | 167 | `.claude/skills/agent_bench_new/templates/phase1a-variant-generation.md` | Phase 1A テンプレート |
| SKILL.md | 186 | `.claude/skills/agent_bench_new/templates/phase1b-variant-generation.md` | Phase 1B テンプレート |
| SKILL.md | 195 | `.agent_audit/{agent_name}/audit-*.md` | agent_audit スキルの分析結果（Phase 1B で参照、外部スキル依存） |
| SKILL.md | 208 | `.claude/skills/agent_bench_new/templates/phase2-test-document.md` | Phase 2 テンプレート |
| SKILL.md | 211 | `.claude/skills/agent_bench_new/test-document-guide.md` | テスト文書生成ガイド |
| SKILL.md | 274 | `.claude/skills/agent_bench_new/templates/phase4-scoring.md` | Phase 4 テンプレート |
| SKILL.md | 276 | `.claude/skills/agent_bench_new/scoring-rubric.md` | 採点基準 |
| SKILL.md | 296 | `.claude/skills/agent_bench_new/templates/phase5-analysis-report.md` | Phase 5 テンプレート |
| SKILL.md | 349 | `.claude/skills/agent_bench_new/templates/phase6a-knowledge-update.md` | Phase 6A テンプレート |
| SKILL.md | 358 | `.claude/skills/agent_bench_new/templates/phase6b-proven-techniques-update.md` | Phase 6B テンプレート |

**重要な外部依存**: SKILL.md 195行目の `.agent_audit/{agent_name}/` は agent_audit スキルが生成するディレクトリ。Phase 1B で参照するが、存在しない場合は空文字列として処理される（SKILL.md 199行目にドキュメント記載あり）。

## D. コンテキスト予算分析
- SKILL.md 行数: 397行
- テンプレートファイル数: 13個、平均行数: 50.8行
- サブエージェント委譲: あり（Phase 0（knowledge初期化 + perspective生成 + 4並列批評）、Phase 1A/1B、Phase 2、Phase 3（並列評価 N×2）、Phase 4（並列採点 N）、Phase 5、Phase 6A/6B 並列）
- 親コンテキストに保持される情報:
  - Phase 0: agent_name, agent_path, perspective 解決結果（検索/自動生成）、累計ラウンド数
  - Phase 1A/1B: バリアント生成サマリ（返答テキスト）、プロンプトファイルパス一覧
  - Phase 2: テスト文書サマリ（返答テキスト）、埋め込み問題一覧（表形式）
  - Phase 3: 評価タスク成功数、失敗タスク情報（リトライ判定用）
  - Phase 4: 各プロンプトのスコアサマリ（1行/プロンプト）
  - Phase 5: 7行サマリ（recommended, reason, convergence, scores, variants, deploy_info, user_summary）
  - Phase 6: ユーザー選択プロンプト、性能推移テーブル（knowledge.md から抽出）
- 3ホップパターンの有無: なし（Phase 5 の分析結果は Phase 6A/6B がファイル経由で参照。Phase 4 の採点結果も Phase 5 がファイル経由で参照）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時の確認 | 不明（明示的記載なし） |
| Phase 0（perspective自動生成） | AskUserQuestion | エージェント定義不足時の要件ヒアリング | 不明（明示的記載なし） |
| Phase 3 | AskUserQuestion | 評価失敗時の再試行/除外/中断判定 | 不明（明示的記載なし） |
| Phase 4 | AskUserQuestion | 採点失敗時の再試行/除外/中断判定 | 不明（明示的記載なし） |
| Phase 6 Step 1 | AskUserQuestion | プロンプト選択（性能推移テーブル + 推奨理由を提示） | 不明（明示的記載なし） |
| Phase 6 Step 3 | AskUserQuestion | 次ラウンド/終了の選択（収束判定・累計ラウンド数を提示） | 不明（明示的記載なし） |

## F. エラーハンドリングパターン
- ファイル不在時:
  - `agent_path` 読み込み失敗（Phase 0）: エラー出力して終了
  - `perspective-source.md` 不在（Phase 0）: フォールバック検索 → 自動生成
  - `knowledge.md` 不在（Phase 0）: 初期化処理を実行し Phase 1A へ
  - `perspective.md` 不在（Phase 0）: エラー（perspective 解決後は必ず存在するはず）
  - `.agent_audit/{agent_name}/audit-*.md` 不在（Phase 1B）: 空文字列として処理し knowledge.md のみで判定
- サブエージェント失敗時:
  - Phase 3（評価実行）: 成功数を集計し、全プロンプトで最低1回の成功結果がある場合は警告出力して Phase 4 へ進む。いずれかのプロンプトで成功0回の場合は AskUserQuestion で確認（再試行/除外/中断）
  - Phase 4（採点）: 失敗した場合 AskUserQuestion で確認（再試行/除外/中断）。ベースライン採点が失敗した場合は中断
  - その他のサブエージェント失敗: 明示的記載なし（未定義）
- 部分完了時:
  - Phase 3: Run2 失敗時は SD = N/A として Phase 4/5 へ進む（SKILL.md 257行目、phase4-scoring.md 6行目、phase5-analysis-report.md 13行目に明示）
  - Phase 4: 一部プロンプトの採点失敗時は除外して Phase 5 へ進む選択肢あり（ただしベースライン失敗時は中断）
- 入力バリデーション:
  - `agent_path` 引数検証: 未指定の場合 AskUserQuestion で確認
  - perspective 自動生成後の検証: 必須セクション（概要/評価スコープ/スコープ外/ボーナス・ペナルティ判定指針/問題バンク）の存在確認。検証失敗時はエラー出力して終了
  - その他のバリデーション: 明示的記載なし

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0（knowledge初期化） | sonnet | templates/knowledge-init-template.md | 1行（"knowledge.md 初期化完了（バリエーション数: {N}）"） | 1 |
| Phase 0（perspective生成） | sonnet | templates/perspective/generate-perspective.md | 4行（観点名、入力型、評価スコープ、問題バンク件数） | 1 |
| Phase 0（perspective批評） | sonnet | templates/perspective/critic-{4種}.md | SendMessage で報告（詳細行数は可変） | 4並列 |
| Phase 0（perspective再生成） | sonnet | templates/perspective/generate-perspective.md | 4行（同上） | 1（条件付き） |
| Phase 1A | sonnet | templates/phase1a-variant-generation.md | 可変（エージェント定義、構造分析結果、バリアント2個の詳細） | 1 |
| Phase 1B | sonnet | templates/phase1b-variant-generation.md | 可変（選定プロセス、バリアント2個の詳細） | 1 |
| Phase 2 | sonnet | templates/phase2-test-document.md | 可変（テスト文書サマリ、埋め込み問題一覧表、ボーナス問題リスト） | 1 |
| Phase 3 | sonnet | （テンプレートなし、直接指示） | 1行（"保存完了: {result_path}"） | N×2（プロンプト数×2回） |
| Phase 4 | sonnet | templates/phase4-scoring.md | 2行（"{prompt_name}: Mean={X.X}, SD={X.X}" + "Run1={X.X}(...), Run2={X.X}(...)"） | N（プロンプト数） |
| Phase 5 | sonnet | templates/phase5-analysis-report.md | 7行（recommended, reason, convergence, scores, variants, deploy_info, user_summary） | 1 |
| Phase 6 Step 1（デプロイ） | haiku | （テンプレートなし、直接指示） | 1行（"デプロイ完了: {agent_path}"） | 1（条件付き） |
| Phase 6 Step 2A | sonnet | templates/phase6a-knowledge-update.md | 1行（"knowledge.md 更新完了（累計ラウンド数: {N}）"） | 1 |
| Phase 6 Step 2B | sonnet | templates/phase6b-proven-techniques-update.md | 1行（"proven-techniques.md 更新完了（promoted: {N}件, updated: {M}件, skipped: {K}件）" または "proven-techniques.md 更新なし（promotion条件未達）"） | 1 |
