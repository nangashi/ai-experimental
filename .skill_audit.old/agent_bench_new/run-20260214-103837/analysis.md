# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 383 | メインワークフロー定義。Phase 0-6の全フローを記述 |
| approach-catalog.md | 202 | 改善アプローチカタログ（S/C/N/M の4カテゴリ、テクニック、バリエーション階層） |
| scoring-rubric.md | 70 | 採点基準（検出判定 ○/△/×、スコア計算式、推奨判定基準、収束判定） |
| proven-techniques.md | 70 | エージェント横断の実証済みテクニック（効果的/アンチパターン/条件付き） |
| test-document-guide.md | 254 | テスト対象文書と正解キー生成ガイド（入力型判定、問題埋め込み、正解キーフォーマット） |
| templates/knowledge-init-template.md | 53 | Phase 0: knowledge.md 初期化テンプレート |
| templates/phase1a-variant-generation.md | 41 | Phase 1A: 初回バリアント生成（ベースライン構築ガイドに基づく） |
| templates/phase1b-variant-generation.md | 33 | Phase 1B: 継続バリアント生成（knowledge.md の知見ベース、audit 結果参照） |
| templates/phase2-test-document.md | 33 | Phase 2: テスト対象文書+正解キー生成 |
| templates/phase3-evaluation.md | 7 | Phase 3: プロンプト実行（テスト対象文書に対する評価実行） |
| templates/phase4-scoring.md | 13 | Phase 4: 採点（正解キーとの照合、ボーナス/ペナルティ判定） |
| templates/phase5-analysis-report.md | 22 | Phase 5: 比較分析レポート作成、推奨判定、収束判定 |
| templates/phase6a-knowledge-update.md | 26 | Phase 6A: knowledge.md 更新（効果テーブル、バリエーションステータス、スコア推移、考慮事項統合） |
| templates/phase6b-proven-techniques-update.md | 52 | Phase 6B: proven-techniques.md 更新（昇格条件判定、Tier 1/2/3、エントリ統合） |
| templates/perspective/generate-perspective.md | 67 | Phase 0: perspective 初期生成（ユーザー要件→観点定義） |
| templates/perspective/critic-clarity.md | 74 | Phase 0: 明確性批評（表現の曖昧性、AI動作一貫性、実行可能性） |
| templates/perspective/critic-effectiveness.md | 73 | Phase 0: 有効性批評（品質寄与度、他観点との境界） |
| templates/perspective/critic-completeness.md | 103 | Phase 0: 網羅性批評（スコープカバレッジ、欠落検出能力、問題バンク品質） |
| templates/perspective/critic-generality.md | 79 | Phase 0: 汎用性批評（業界依存性、規制依存性、技術スタック依存性） |
| perspectives/code/best-practices.md | 34 | 事前定義perspective: コードレビュー（ベストプラクティス観点） |
| perspectives/code/maintainability.md | 未読 | 事前定義perspective: コードレビュー（保守性観点） |
| perspectives/code/security.md | 未読 | 事前定義perspective: コードレビュー（セキュリティ観点） |
| perspectives/code/performance.md | 未読 | 事前定義perspective: コードレビュー（パフォーマンス観点） |
| perspectives/code/consistency.md | 未読 | 事前定義perspective: コードレビュー（一貫性観点） |
| perspectives/design/consistency.md | 未読 | 事前定義perspective: 設計レビュー（一貫性観点） |
| perspectives/design/security.md | 43 | 事前定義perspective: 設計レビュー（セキュリティ観点） |
| perspectives/design/performance.md | 未読 | 事前定義perspective: 設計レビュー（パフォーマンス観点） |
| perspectives/design/reliability.md | 未読 | 事前定義perspective: 設計レビュー（信頼性観点） |
| perspectives/design/structural-quality.md | 未読 | 事前定義perspective: 設計レビュー（構造品質観点） |
| perspectives/design/old/maintainability.md | 未読 | 廃止済みperspective |
| perspectives/design/old/best-practices.md | 未読 | 廃止済みperspective |

## B. ワークフロー概要
- **フェーズ構成**: Phase 0 → Phase 1A/1B → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 → (ループバック Phase 1B または 終了)

### 各フェーズの目的
- **Phase 0 (初期化・状態検出)**: エージェントファイル読み込み、agent_name 導出、perspective 解決（検索→自動生成）、knowledge.md 初期化判定
- **Phase 1A (初回バリアント生成)**: ベースライン作成 + proven-techniques.md のベースライン構築ガイドに基づく2バリアント生成
- **Phase 1B (継続バリアント生成)**: knowledge.md の知見ベースで Broad/Deep モード判定、UNTESTED/EFFECTIVE バリエーション選択、agent_audit 結果参照
- **Phase 2 (テスト入力文書生成)**: test-document-guide.md に従い、入力型判定、8-10問題埋め込み、正解キー生成
- **Phase 3 (並列評価実行)**: 各プロンプト × 2回を並列実行（Task ツール、結果ファイル保存）
- **Phase 4 (採点)**: 各プロンプトの Run1/Run2 を正解キーと照合、検出判定 ○/△/×、ボーナス/ペナルティ、スコア計算
- **Phase 5 (分析・推奨判定)**: 比較レポート作成、推奨判定基準適用、収束判定、7行サマリ返答
- **Phase 6 (デプロイ・ナレッジ更新)**: Step 1: ユーザーにプロンプト選択提示+デプロイ、Step 2A: knowledge.md 更新、Step 2B: proven-techniques.md 更新（昇格条件判定）、Step 2C: 次アクション選択（次ラウンド/終了）

### データフロー
- **Phase 0 生成**: `.agent_bench/{agent_name}/perspective-source.md`, `perspective.md`, `knowledge.md`
- **Phase 1A/1B 生成**: `.agent_bench/{agent_name}/prompts/v{NNN}-baseline.md`, `v{NNN}-variant-*.md`
- **Phase 2 生成**: `.agent_bench/{agent_name}/test-document-round-{NNN}.md`, `answer-key-round-{NNN}.md`
- **Phase 3 生成**: `.agent_bench/{agent_name}/results/v{NNN}-{name}-run{R}.md`
- **Phase 4 生成**: `.agent_bench/{agent_name}/results/v{NNN}-{name}-scoring.md`
- **Phase 5 生成**: `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md`
- **Phase 6 更新**: `{agent_path}` (デプロイ), `knowledge.md`, `proven-techniques.md`

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| templates/phase1b-variant-generation.md | 8-9 | `.agent_audit/{agent_name}/audit-dim1.md`, `audit-dim2.md` | agent_audit の分析結果をバリアント生成時に参照（ファイル不在時は空文字列を渡す） |
| SKILL.md | 179-180 | `.agent_audit/{agent_name}/audit-dim1.md`, `audit-dim2.md` | Phase 1B で agent_audit の分析結果をサブエージェントに渡す |

## D. コンテキスト予算分析
- **SKILL.md 行数**: 383行
- **テンプレートファイル数**: 14個、平均行数: 48行
- **サブエージェント委譲**: あり（Phase 0: 初期化+perspective生成+4並列批評、Phase 1A/1B: バリアント生成、Phase 2: テスト文書生成、Phase 3: 並列評価、Phase 4: 並列採点、Phase 5: 分析レポート、Phase 6A: knowledge更新、Phase 6B: proven-techniques更新）
- **親コンテキストに保持される情報**:
  - Phase 0: agent_path, agent_name, perspective解決状態、知見蓄積状況（初回/継続）
  - Phase 1: 生成バリアント数、バリアント名リスト、Variation ID、仮説サマリ
  - Phase 2: 問題サマリ（ID, カテゴリ, 深刻度, 概要1行）
  - Phase 3: 評価成功数/失敗数、プロンプト名リスト
  - Phase 4: スコアサマリ（各プロンプトの Mean, SD, Run1/Run2 詳細）
  - Phase 5: 7行サマリ（recommended, reason, convergence, scores, variants, deploy_info, user_summary）
  - Phase 6: デプロイ完了確認、knowledge.md/proven-techniques.md 更新確認
- **3ホップパターンの有無**: なし（全データフローがファイル経由）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0: perspective 自動生成 Step 1 | AskUserQuestion | エージェント定義が50文字未満または目的・評価基準・入力型・出力型が不明な場合の要件ヒアリング | 不明 |
| Phase 3: 並列評価 | AskUserQuestion | いずれかのプロンプトで成功結果が0回の場合: 再試行/除外して続行/中断を確認 | 不明 |
| Phase 4: 採点 | AskUserQuestion | 採点失敗時: 再試行/除外して続行/中断を確認 | 不明 |
| Phase 6 Step 1: プロンプト選択 | AskUserQuestion | ラウンド別性能推移テーブルと推奨プロンプトを提示し、デプロイするプロンプトをユーザーに選択させる | 不明 |
| Phase 6 Step 2C: 次アクション | AskUserQuestion | 次ラウンド継続/終了を確認（収束判定・累計ラウンド数に応じた推奨付き） | 不明 |

## F. エラーハンドリングパターン
- **ファイル不在時**:
  - agent_path 読み込み失敗時: エラー出力して終了
  - perspective-source.md 不在時: 自動生成フロー実行（ファイル名パターン検索 → perspective 自動生成）
  - knowledge.md 不在時: 初期化テンプレートで生成し Phase 1A へ
  - knowledge.md 存在時: Phase 1B へ
  - audit-dim1.md/audit-dim2.md 不在時: 空文字列を渡す（Phase 1B）
  - reference_perspective_path 不在時: 空文字列を渡す（perspective 生成時）
- **サブエージェント失敗時**:
  - Phase 3 評価失敗: 成功数に応じて分岐（全プロンプト最低1回成功 → Phase 4、一部プロンプト0回 → AskUserQuestion で再試行/除外/中断）
  - Phase 4 採点失敗: AskUserQuestion で再試行/除外/中断（ベースライン失敗時は中断）
  - perspective 生成検証失敗: エラー出力してスキル終了
- **部分完了時**:
  - Phase 3: 各プロンプトに最低1回の成功結果があれば Phase 4 へ進む（SD = N/A のプロンプトが生じる）
  - Phase 4: ベースライン以外の採点失敗は除外して続行可能
- **入力バリデーション**:
  - agent_path 未指定時: AskUserQuestion で確認
  - perspective 生成検証: 必須セクション（概要、評価スコープ、スコープ外、ボーナス/ペナルティ、問題バンク）の存在確認

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0: knowledge 初期化 | sonnet | knowledge-init-template.md | 1行（「knowledge.md 初期化完了（バリエーション数: {N}）」） | 1 |
| Phase 0: perspective 生成 | sonnet | perspective/generate-perspective.md | 4行サマリ（観点、入力型、評価スコープ、問題バンク） | 1 |
| Phase 0: 4並列批評 | sonnet | critic-effectiveness.md, critic-completeness.md, critic-clarity.md, critic-generality.md | 各サブエージェントの批評結果セクション | 4 |
| Phase 1A: バリアント生成 | sonnet | phase1a-variant-generation.md | エージェント定義+構造分析+バリアント仮説（セクション構造） | 1 |
| Phase 1B: バリアント生成 | sonnet | phase1b-variant-generation.md | 選定プロセス+バリアント仮説（セクション構造） | 1 |
| Phase 2: テスト文書生成 | sonnet | phase2-test-document.md | テスト対象文書サマリ+問題一覧+ボーナス問題リスト（セクション構造） | 1 |
| Phase 3: 並列評価 | sonnet | phase3-evaluation.md | 1行（「保存完了: {result_path}」） | (ベースライン+バリアント数) × 2回 |
| Phase 4: 並列採点 | sonnet | phase4-scoring.md | 2行（{prompt_name}: Mean/SD、Run1/Run2詳細） | ベースライン+バリアント数 |
| Phase 5: 分析レポート | sonnet | phase5-analysis-report.md | 7行サマリ（recommended, reason, convergence, scores, variants, deploy_info, user_summary） | 1 |
| Phase 6 Step 1: デプロイ | haiku | プロンプト内直接指示（Benchmark Metadata除去+上書き保存） | 1行（「デプロイ完了: {agent_path}」） | 1（ベースライン以外選択時のみ） |
| Phase 6 Step 2A: knowledge 更新 | sonnet | phase6a-knowledge-update.md | 1行（「knowledge.md 更新完了（累計ラウンド数: {N}）」） | 1 |
| Phase 6 Step 2B: proven-techniques 更新 | sonnet | phase6b-proven-techniques-update.md | 1行（「proven-techniques.md 更新完了/なし」） | 1 |
