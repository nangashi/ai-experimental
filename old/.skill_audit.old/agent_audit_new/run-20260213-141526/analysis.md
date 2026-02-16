# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 380 | スキルのメインワークフロー定義。Phase 0〜6の全手順を記載 |
| approach-catalog.md | 202 | 改善アプローチカタログ。カテゴリ→テクニック→バリエーションの3階層管理 |
| scoring-rubric.md | 70 | 採点基準。検出判定基準、スコア計算式、推奨判定基準を定義 |
| proven-techniques.md | 70 | 実証済みテクニック。エージェント横断の知見を自動集約 |
| test-document-guide.md | 254 | テスト対象文書生成ガイド。入力型判定、文書構成、問題埋め込み指針 |
| templates/phase1a-variant-generation.md | 41 | Phase 1A（初回）のバリアント生成テンプレート |
| templates/phase1b-variant-generation.md | 42 | Phase 1B（継続）のバリアント生成テンプレート |
| templates/phase2-test-document.md | 31 | Phase 2 のテスト対象文書生成テンプレート |
| templates/phase4-scoring.md | 13 | Phase 4 の採点テンプレート |
| templates/phase5-analysis-report.md | 21 | Phase 5 の分析・推奨判定テンプレート |
| templates/phase6a-knowledge-update.md | 26 | Phase 6A のナレッジ更新テンプレート |
| templates/phase6b-proven-techniques-update.md | 51 | Phase 6B のスキル知見フィードバックテンプレート |
| templates/knowledge-init-template.md | 53 | knowledge.md 初期化テンプレート |
| templates/perspective/generate-perspective.md | 67 | perspective 自動生成テンプレート |
| templates/perspective/critic-completeness.md | 107 | perspective 批評（網羅性）テンプレート |
| templates/perspective/critic-clarity.md | 76 | perspective 批評（明確性）テンプレート |
| templates/perspective/critic-effectiveness.md | 75 | perspective 批評（有効性）テンプレート |
| templates/perspective/critic-generality.md | 82 | perspective 批評（汎用性）テンプレート |
| perspectives/design/security.md | 43 | 設計レビュー用セキュリティ観点定義 |
| perspectives/design/consistency.md | 未読 | 設計レビュー用一貫性観点定義 |
| perspectives/design/structural-quality.md | 未読 | 設計レビュー用構造品質観点定義 |
| perspectives/design/performance.md | 未読 | 設計レビュー用パフォーマンス観点定義 |
| perspectives/design/reliability.md | 未読 | 設計レビュー用信頼性観点定義 |
| perspectives/code/maintainability.md | 34 | コードレビュー用保守性観点定義 |
| perspectives/code/security.md | 未読 | コードレビュー用セキュリティ観点定義 |
| perspectives/code/performance.md | 未読 | コードレビュー用パフォーマンス観点定義 |
| perspectives/code/best-practices.md | 未読 | コードレビュー用ベストプラクティス観点定義 |
| perspectives/code/consistency.md | 未読 | コードレビュー用一貫性観点定義 |
| perspectives/design/old/maintainability.md | 未読 | 旧版（アーカイブ） |
| perspectives/design/old/best-practices.md | 未読 | 旧版（アーカイブ） |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → 1A/1B → 2 → 3 → 4 → 5 → 6 (→ 1B ループ)
- 各フェーズの目的:
  - Phase 0: 初期化・状態検出（agent_name 導出、perspective 解決/自動生成、knowledge.md 初期化）
  - Phase 1A: 初回 — ベースライン作成 + バリアント生成（proven-techniques ガイド適用）
  - Phase 1B: 継続 — 知見ベースのバリアント生成（knowledge.md + agent_audit 分析結果を参照）
  - Phase 2: テスト入力文書生成（毎ラウンド実行。perspective + 問題バンクに基づく）
  - Phase 3: 並列評価実行（全プロンプト × 2回の並列実行）
  - Phase 4: 採点（サブエージェントの並列実行。検出判定 + ボーナス/ペナルティ）
  - Phase 5: 分析・推奨判定・レポート作成（推奨判定基準適用）
  - Phase 6: プロンプト選択・デプロイ・次アクション（ナレッジ更新 + スキル知見フィードバック + ループ判定）
- データフロー:
  - Phase 0 → perspective-source.md, perspective.md, knowledge.md 生成
  - Phase 1A/1B → prompts/v{NNN}-*.md 生成
  - Phase 2 → test-document-round-{NNN}.md, answer-key-round-{NNN}.md 生成
  - Phase 3 → results/v{NNN}-{name}-run{R}.md 生成
  - Phase 4 → results/v{NNN}-{name}-scoring.md 生成（Phase 5 で参照）
  - Phase 5 → reports/round-{NNN}-comparison.md 生成（Phase 6A/6B で参照）
  - Phase 6A → knowledge.md 更新（Phase 1B で参照）
  - Phase 6B → proven-techniques.md 更新（Phase 1A/1B で参照）

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 83 | `.claude/skills/agent_bench/templates/perspective/generate-perspective.md` | perspective 自動生成テンプレート（誤記: agent_bench → agent_bench_new） |
| SKILL.md | 94 | `.claude/skills/agent_bench/templates/perspective/{テンプレート名}` | perspective 批評テンプレート（誤記: agent_bench → agent_bench_new） |
| SKILL.md | 126 | `.claude/skills/agent_bench/templates/knowledge-init-template.md` | knowledge.md 初期化テンプレート（誤記: agent_bench → agent_bench_new） |
| SKILL.md | 129 | `.claude/skills/agent_bench/approach-catalog.md` | アプローチカタログ（誤記: agent_bench → agent_bench_new） |
| SKILL.md | 148 | `.claude/skills/agent_bench/templates/phase1a-variant-generation.md` | Phase 1A テンプレート（誤記: agent_bench → agent_bench_new） |
| SKILL.md | 152-154 | `.claude/skills/agent_bench/approach-catalog.md`, `proven-techniques.md`, `perspective-source.md`, `perspective.md` | Phase 1A 参照ファイル（誤記: agent_bench → agent_bench_new） |
| SKILL.md | 168 | `.claude/skills/agent_bench/templates/phase1b-variant-generation.md` | Phase 1B テンプレート（誤記: agent_bench → agent_bench_new） |
| SKILL.md | 176-178 | `.agent_audit/{agent_name}/audit-*.md` | agent_audit スキルが生成する分析結果（外部スキル依存） |
| SKILL.md | 190 | `.claude/skills/agent_bench/templates/phase2-test-document.md` | Phase 2 テンプレート（誤記: agent_bench → agent_bench_new） |
| SKILL.md | 192-193 | `.claude/skills/agent_bench/test-document-guide.md` | テスト対象文書ガイド（誤記: agent_bench → agent_bench_new） |
| SKILL.md | 255 | `.claude/skills/agent_bench/templates/phase4-scoring.md` | Phase 4 テンプレート（誤記: agent_bench → agent_bench_new） |
| SKILL.md | 257 | `.claude/skills/agent_bench/scoring-rubric.md` | 採点基準（誤記: agent_bench → agent_bench_new） |
| SKILL.md | 278 | `.claude/skills/agent_bench/templates/phase5-analysis-report.md` | Phase 5 テンプレート（誤記: agent_bench → agent_bench_new） |
| SKILL.md | 280 | `.claude/skills/agent_bench/scoring-rubric.md` | 採点基準（誤記: agent_bench → agent_bench_new） |
| SKILL.md | 330 | `.claude/skills/agent_bench/templates/phase6a-knowledge-update.md` | Phase 6A テンプレート（誤記: agent_bench → agent_bench_new） |
| SKILL.md | 341 | `.claude/skills/agent_bench/templates/phase6b-proven-techniques-update.md` | Phase 6B テンプレート（誤記: agent_bench → agent_bench_new） |
| SKILL.md | 344 | `.claude/skills/agent_bench/proven-techniques.md` | 実証済みテクニック（誤記: agent_bench → agent_bench_new） |
| templates/phase1a-variant-generation.md | 4-6 | `{proven_techniques_path}`, `{approach_catalog_path}`, `{perspective_source_path}` | Phase 1A 参照ファイル（パス変数経由） |
| templates/phase1b-variant-generation.md | 14-17 | `{knowledge_path}`, `{agent_path}`, `{proven_techniques_path}`, `{perspective_path}`, `{audit_dim1_path}`, `{audit_dim2_path}` | Phase 1B 参照ファイル（パス変数経由） |
| templates/phase2-test-document.md | 4-6 | `{test_document_guide_path}`, `{perspective_source_path}`, `{knowledge_path}` | Phase 2 参照ファイル（パス変数経由） |
| templates/phase4-scoring.md | 3-6 | `{scoring_rubric_path}`, `{answer_key_path}`, `{perspective_path}`, `{result_run1_path}`, `{result_run2_path}` | Phase 4 参照ファイル（パス変数経由） |
| templates/phase5-analysis-report.md | 4-7 | `{scoring_rubric_path}`, `{knowledge_path}`, `{scoring_file_paths}` | Phase 5 参照ファイル（パス変数経由） |
| templates/phase6a-knowledge-update.md | 4-5 | `{knowledge_path}`, `{report_save_path}` | Phase 6A 参照ファイル（パス変数経由） |
| templates/phase6b-proven-techniques-update.md | 4-6 | `{proven_techniques_path}`, `{knowledge_path}`, `{report_save_path}` | Phase 6B 参照ファイル（パス変数経由） |
| templates/knowledge-init-template.md | 3-4 | `{approach_catalog_path}`, `{perspective_source_path}` | knowledge.md 初期化時の参照ファイル（パス変数経由） |

**重要な発見**: SKILL.md 内の全テンプレート参照パスが `.claude/skills/agent_bench/` になっているが、正しくは `.claude/skills/agent_bench_new/` であるべき。これは誤記であり、実行時エラーの原因となる可能性がある。

## D. コンテキスト予算分析
- SKILL.md 行数: 380行
- テンプレートファイル数: 13個、平均行数: 約50行
- サブエージェント委譲: あり（Phase 0, 1A, 1B, 2, 3, 4, 5, 6A, 6B で委譲）
- 親コンテキストに保持される情報:
  - Phase 0: agent_name, agent_path, perspective 検出結果（ソース/自動生成）、累計ラウンド数
  - Phase 1A/1B: サブエージェント返答（バリアントサマリ）
  - Phase 2: サブエージェント返答（テスト文書サマリ）
  - Phase 3: 成功数・失敗数の集計結果
  - Phase 4: サブエージェント返答（スコアサマリ）
  - Phase 5: サブエージェント返答（7行サマリ: recommended, reason, convergence, scores, variants, deploy_info, user_summary）
  - Phase 6: ユーザー選択結果、累計ラウンド数
- 3ホップパターンの有無: なし（サブエージェント間のデータ受け渡しはファイル経由で実施。例: Phase 5 は Phase 4 の採点ファイルを直接 Read、親は中継しない）

**評価**: コンテキスト節約の原則（SKILL.md 行18-24）に従い、親コンテキストには要約・メタデータのみ保持する設計。Phase 4 の採点詳細を親に返さず Phase 5 で直接ファイルから読み込む点など、3ホップパターンの回避が徹底されている。

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時の確認 | 不明 |
| Phase 0 | AskUserQuestion | perspective 自動生成時、エージェント定義が実質空の場合のヒアリング（目的、入出力、制約） | 不明 |
| Phase 3 | AskUserQuestion | 評価失敗時の対応選択（再試行/除外/中断） | 不明 |
| Phase 4 | AskUserQuestion | 採点失敗時の対応選択（再試行/除外/中断） | 不明 |
| Phase 6 Step 1 | AskUserQuestion | プロンプト選択（推奨含む全プロンプトから選択） | 不明 |
| Phase 6 Step 2C | AskUserQuestion | 次アクション選択（次ラウンド/終了） | 不明 |

**評価**: 合計6箇所の確認ポイント。SKILL.md には Fast mode に関する記述なし。MEMORY.md（行26）では「fastモードで中間確認をスキップ可能に」の方針が記載されているが、SKILL.md 本文には未反映。

## F. エラーハンドリングパターン
- ファイル不在時:
  - agent_path 不在（Phase 0 行38）: エラー出力して終了
  - knowledge.md 不在（Phase 0 行120）: 初期化して Phase 1A へ（正常フロー）
  - perspective-source.md 不在（Phase 0 行50-56）: パターンマッチング → 既存 perspective 検索 → 自動生成（フォールバック）
  - 既存 perspective 検索失敗（Phase 0 行56）: 自動生成にフォールバック
  - perspective 自動生成後の検証失敗（Phase 0 行114）: エラー出力してスキル終了
- サブエージェント失敗時:
  - Phase 3 評価失敗（行235-242）: 成功数に応じて分岐。全失敗時は AskUserQuestion で確認（再試行/除外/中断）
  - Phase 4 採点失敗（行264-270）: 同上。ベースライン失敗時は中断
  - その他フェーズ: 未定義
- 部分完了時:
  - Phase 3（行238）: 各プロンプトに最低1回の成功結果があれば警告を出力し Phase 4 へ進む（SD = N/A として扱う）
  - Phase 4（行269）: 成功したプロンプトのみで Phase 5 へ進む（ベースライン失敗時は中断）
- 入力バリデーション: agent_path の読み込み成功確認のみ（Phase 0 行38）。その他の入力検証は未定義

**評価**: Phase 3/4 のサブエージェント失敗時の対応は明確。ただし、Phase 1A, 1B, 2, 5, 6A, 6B のサブエージェント失敗時の処理は未定義。部分完了時の継続基準は合理的。

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0 (perspective 自動生成 Step 3) | sonnet | perspective/generate-perspective.md | 4行（観点名、入力型、評価スコープ、問題バンク件数） | 1 |
| Phase 0 (perspective 自動生成 Step 4) | sonnet | perspective/critic-effectiveness.md, critic-completeness.md, critic-clarity.md, critic-generality.md | 未定義（SendMessage で報告） | 4（並列） |
| Phase 0 (perspective 自動生成 Step 5) | sonnet | perspective/generate-perspective.md（再生成） | 4行 | 1 |
| Phase 0 (knowledge 初期化) | sonnet | knowledge-init-template.md | 1行（初期化完了） | 1 |
| Phase 1A | sonnet | phase1a-variant-generation.md | 複数行（構造分析結果 + バリアントサマリ） | 1 |
| Phase 1B | sonnet | phase1b-variant-generation.md | 複数行（選定プロセス + バリアントサマリ） | 1 |
| Phase 2 | sonnet | phase2-test-document.md | 複数行（テスト文書サマリ + 問題一覧） | 1 |
| Phase 3 | sonnet | （テンプレートなし。SKILL.md 内に直接指示文） | 1行（保存完了メッセージ） | (ベースライン + バリアント数) × 2回 |
| Phase 4 | sonnet | phase4-scoring.md | 2行（スコアサマリ） | ベースライン + バリアント数 |
| Phase 5 | sonnet | phase5-analysis-report.md | 7行（recommended, reason, convergence, scores, variants, deploy_info, user_summary） | 1 |
| Phase 6 Step 1 (デプロイ) | haiku | （テンプレートなし。SKILL.md 内に直接指示文） | 1行（デプロイ完了） | 1 |
| Phase 6A | sonnet | phase6a-knowledge-update.md | 1行（更新完了） | 1 |
| Phase 6B | sonnet | phase6b-proven-techniques-update.md | 1行（更新完了 or 更新なし） | 1 |

**評価**: サブエージェントの返答行数は最小化されており、コンテキスト節約の原則に従っている。Phase 3 のみ並列数が動的（プロンプト数 × 2回）。perspective 自動生成の批評フェーズは4並列で効率的。
