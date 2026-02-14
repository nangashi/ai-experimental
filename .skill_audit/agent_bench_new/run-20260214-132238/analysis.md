# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 337 | メインスキル定義。全7フェーズのワークフロー制御 |
| approach-catalog.md | 202 | 改善アプローチカタログ（4カテゴリ: S/C/N/M、共通ルール・推奨構成） |
| scoring-rubric.md | 70 | 採点基準定義（検出判定○△×、スコア計算式、推奨判定基準） |
| proven-techniques.md | 70 | エージェント横断の実証済み知見（自動集約、4セクション） |
| test-document-guide.md | 254 | テスト対象文書生成ガイド（入力型判定、構成、問題埋め込み） |
| templates/phase1a-variant-generation.md | 41 | Phase 1A: ベースライン作成+バリアント生成（初回専用） |
| templates/phase1b-variant-generation.md | 32 | Phase 1B: 知見ベースバリアント生成（継続用） |
| templates/phase2-test-document.md | 32 | Phase 2: テスト対象文書と正解キー生成 |
| templates/phase4-scoring.md | 12 | Phase 4: 採点実行（問題別検出判定、ボーナス/ペナルティ） |
| templates/phase5-analysis-report.md | 21 | Phase 5: 比較レポート作成と推奨判定 |
| templates/phase6a-knowledge-update.md | 26 | Phase 6A: エージェント単位knowledge.md更新 |
| templates/phase6b-proven-techniques-update.md | 51 | Phase 6B: スキル横断proven-techniques.md更新 |
| templates/knowledge-init-template.md | 60 | Phase 0: knowledge.md初期化（バリエーションステータステーブル含む） |
| templates/perspective/orchestrate-perspective-generation.md | 62 | Phase 0: perspective自動生成オーケストレーション（Step 3-6） |
| templates/perspective/generate-perspective.md | 66 | perspective初期生成サブエージェント |
| templates/perspective/critic-effectiveness.md | 74 | 批判レビュー: 品質寄与度+境界分析 |
| templates/perspective/critic-completeness.md | 106 | 批判レビュー: 網羅性+未考慮事項+問題バンク |
| templates/perspective/critic-clarity.md | 75 | 批判レビュー: 表現明確性+AI動作一貫性 |
| templates/perspective/critic-generality.md | 81 | 批判レビュー: 汎用性+業界依存性フィルタ |
| perspectives/design/security.md | 43 | 観点定義: セキュリティ（設計レビュー用） |
| perspectives/design/performance.md | 読込未実施 | 観点定義: パフォーマンス（設計） |
| perspectives/design/consistency.md | 読込未実施 | 観点定義: 一貫性（設計） |
| perspectives/design/structural-quality.md | 読込未実施 | 観点定義: 構造品質（設計） |
| perspectives/design/reliability.md | 読込未実施 | 観点定義: 信頼性（設計） |
| perspectives/design/old/maintainability.md | 読込未実施 | 旧観点定義（非推奨） |
| perspectives/design/old/best-practices.md | 読込未実施 | 旧観点定義（非推奨） |
| perspectives/code/security.md | 38 | 観点定義: セキュリティ（コードレビュー用） |
| perspectives/code/performance.md | 読込未実施 | 観点定義: パフォーマンス（コード） |
| perspectives/code/consistency.md | 読込未実施 | 観点定義: 一貫性（コード） |
| perspectives/code/best-practices.md | 読込未実施 | 観点定義: ベストプラクティス（コード） |
| perspectives/code/maintainability.md | 読込未実施 | 観点定義: 保守性（コード） |

## B. ワークフロー概要
- **フェーズ構成**: Phase 0 → 1A/1B → 2 → 3 → 4 → 5 → 6 → (1Bへループまたは終了)
- **Phase 0 (初期化・状態検出)**: エージェントファイル読込、agent_name導出、perspective解決（検索→フォールバック→自動生成）、knowledge.md存在確認（→Phase 1A/1B分岐）
- **Phase 1A (初回ベースライン+バリアント生成)**: knowledge.md不在時。proven-techniques基準でベースライン生成+構造分析+ギャップベースバリアント2個生成+knowledge.md初期化
- **Phase 1B (継続バリアント生成)**: knowledge.md存在時。バリエーションステータステーブル参照しBroad/Deep選定+ベースラインコピー+バリアント2個生成
- **Phase 2 (テスト文書生成)**: 毎ラウンド実行。perspective+問題バンク+過去履歴参照し、テスト対象文書と正解キー生成（8-10問埋込）
- **Phase 3 (並列評価実行)**: プロンプトごとに2回実行（全並列起動）。失敗時はAskUserQuestionで再試行/除外/中断選択
- **Phase 4 (採点)**: プロンプトごとに1採点サブエージェント並列起動。問題別検出判定(○△×)+ボーナス/ペナルティ+スコア計算
- **Phase 5 (分析・推奨判定)**: 比較レポート作成+推奨判定（平均スコア差・SD基準）+収束判定（2ラウンド連続<0.5pt）
- **Phase 6 (デプロイ・更新・次アクション)**: Step 1=ユーザー選択+デプロイ、Step 2-A=knowledge.md更新（効果テーブル+バリエーションステータス+スコア推移）、Step 2-B=proven-techniques.md更新（Tier判定+昇格）、Step 2-C=次アクション選択（次ラウンド→Phase 1Bループ / 終了）

### データフロー
- **Phase 0生成**: `.agent_bench/{agent_name}/perspective-source.md`, `perspective.md`, `knowledge.md`（初回のみ）
- **Phase 1生成**: `.agent_bench/{agent_name}/prompts/v{NNN}-*.md`（ベースライン+バリアント）
- **Phase 2生成**: `.agent_bench/{agent_name}/test-document-round-{NNN}.md`, `answer-key-round-{NNN}.md`
- **Phase 3生成**: `.agent_bench/{agent_name}/results/v{NNN}-{name}-run{1,2}.md`
- **Phase 4生成**: `.agent_bench/{agent_name}/results/v{NNN}-{name}-scoring.md`
- **Phase 5生成**: `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md`
- **Phase 6更新**: `knowledge.md`（累計ラウンド数+効果テーブル+スコア推移）、`proven-techniques.md`（エージェント横断知見集約）、`{agent_path}`（デプロイ）

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 46-47 | `.claude/` | agent_name導出ルール（.claude/配下の場合のパス処理） |
| SKILL.md | 54 | `.agent_bench/{agent_name}/` | perspective-source.md検索 |
| SKILL.md | 58-59 | `.claude/skills/agent_bench_new/perspectives/` | reviewer パターンフォールバック |
| SKILL.md | 63-64 | `.agent_bench/{agent_name}/` | perspective.md保存（作業コピー） |
| SKILL.md | 78 | `.claude/skills/agent_bench_new/perspectives/design/*.md` | 参照perspective検索（自動生成時） |
| SKILL.md | 85-91 | `templates/perspective/orchestrate-perspective-generation.md` | perspective自動生成委譲 |
| SKILL.md | 95 | `.agent_bench/{agent_name}/knowledge.md` | 初回/継続判定 |
| SKILL.md | 103-108 | `templates/knowledge-init-template.md` + approach-catalog.md | knowledge.md初期化 |
| SKILL.md | 125-135 | `templates/phase1a-variant-generation.md` + 各種参照ファイル | Phase 1A委譲 |
| SKILL.md | 145-153 | `templates/phase1b-variant-generation.md` + audit連携 | Phase 1B委譲（`.agent_audit/{agent_name}/audit-dim*.md` 検索） |
| SKILL.md | 163-170 | `templates/phase2-test-document.md` | Phase 2委譲 |
| SKILL.md | 202-203 | `.agent_bench/{agent_name}/test-document-round-{NNN}.md` | Phase 3評価入力 |
| SKILL.md | 228-235 | `templates/phase4-scoring.md` + scoring-rubric.md | Phase 4採点委譲 |
| SKILL.md | 251-256 | `templates/phase5-analysis-report.md` | Phase 5分析委譲 |
| SKILL.md | 290-293 | `templates/phase6a-knowledge-update.md` | Phase 6A委譲 |
| SKILL.md | 302-307 | `templates/phase6b-proven-techniques-update.md` | Phase 6B委譲 |
| proven-techniques.md | 5 | `.agent_bench/` | エージェント実験結果参照元の説明 |
| approach-catalog.md | 201 | `.agent_bench/{agent_name}/knowledge.md` | 詳細参照先の案内 |
| templates/perspective/orchestrate-perspective-generation.md | 10, 18, 30 | スキル内templates | perspective生成サブエージェント委譲 |

**外部参照サマリ**: `.agent_bench/{agent_name}/` (知見蓄積)、`.agent_audit/{agent_name}/` (agent_auditスキルとの連携、オプショナル)、`.claude/` (agent_name導出・perspective検索)

## D. コンテキスト予算分析
- **SKILL.md 行数**: 337行
- **テンプレートファイル数**: 13個、平均行数: 44.2行（最小12行〜最大106行）
- **サブエージェント委譲**: あり（Phase 0/1A/1B/2/3/4/5/6A/6B）
  - **委譲パターン**: 全Phase（0除く）でTaskツール使用。テンプレートファイルをRead→内容に従って処理実行
  - **返答形式**: 最小限（Phase 1=構造分析+バリアント一覧、Phase 2=問題サマリ、Phase 4=スコア1行、Phase 5=7行サマリ、Phase 6A/6B=完了確認）
  - **詳細保存先**: サブエージェントが直接ファイル保存（親経由なし）
- **親コンテキストに保持される情報**:
  - Phase間の制御フロー状態（agent_name, agent_path, perspective解決状態、累計ラウンド数）
  - Phase 5の7行サマリ（Phase 6でデプロイ判定・次アクション選択に使用）
  - プロンプト名リスト（Phase 3→4で並列起動制御）
  - スコアサマリ（Phase 4→5で集約、Phase 6で最終報告）
- **3ホップパターンの有無**: なし（MEMORY.mdで明示的に回避。サブエージェント間のデータ受け渡しはファイル経由）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path未指定時の確認 | 不明 |
| Phase 0（perspective自動生成） | AskUserQuestion | エージェント定義が空または不足時の要件ヒアリング | 不明 |
| Phase 3 | AskUserQuestion | プロンプト評価失敗時（成功結果0回）の対応選択（再試行/除外/中断） | 不明 |
| Phase 4 | AskUserQuestion | 採点失敗時の対応選択（再試行/除外/中断） | 不明 |
| Phase 6 Step 1 | AskUserQuestion | デプロイプロンプト選択（推奨提示+全選択肢） | 不明 |
| Phase 6 Step 2-C | AskUserQuestion | 次アクション選択（次ラウンド/終了、収束判定・累計ラウンド数表示） | 不明（ただしSKIL.md L19-20に「最終判断はユーザーに委ねる」と明記） |

## F. エラーハンドリングパターン
- **ファイル不在時**:
  - エージェントファイル不在（Phase 0）: エラー出力して終了
  - knowledge.md不在（Phase 0）: 初期化してPhase 1Aに分岐
  - perspective不在（Phase 0）: 自動生成（reviewer パターンフォールバック→4並列批判レビュー→再生成1回→検証）
  - perspective自動生成検証失敗（Phase 0）: エラー出力して終了
  - audit-dim1/dim2不在（Phase 1B）: 変数を渡さない（オプショナル参照）
- **サブエージェント失敗時**:
  - Phase 3（評価実行）失敗: 成功数で分岐。全失敗→AskUserQuestion（再試行/除外/中断）、部分失敗→警告出力して継続（成功Run のみで採点）
  - Phase 4（採点）失敗: AskUserQuestion（再試行/除外/中断）、ベースライン失敗時は中断
  - その他Phase: 未定義（サブエージェント完了前提）
- **部分完了時**:
  - Phase 3: 各プロンプトに最低1回の成功結果がある場合は警告付きで継続（Run 1回のみのプロンプトはSD=N/A）
  - Phase 4: 失敗プロンプトを除外して継続可能（ただしベースライン失敗時は中断）
- **入力バリデーション**: agent_path未指定時のみAskUserQuestionで確認。その他の入力バリデーションは未定義

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0 (perspective自動生成) | sonnet | orchestrate-perspective-generation.md | 4行（generation_status, regeneration_needed, perspective_path, validation_result） | 1 |
| Phase 0 (perspective初期生成) | sonnet | perspective/generate-perspective.md | （オーケストレータ経由） | 1（オーケストレータ内） |
| Phase 0 (批判レビュー) | sonnet | perspective/critic-{effectiveness,completeness,clarity,generality}.md | （オーケストレータ経由） | 4並列（オーケストレータ内） |
| Phase 0 (knowledge初期化) | sonnet | knowledge-init-template.md | 1行（初期化完了+バリエーション数） | 1 |
| Phase 1A | sonnet | phase1a-variant-generation.md | 構造分析テーブル+バリアント一覧（セクション3個） | 1 |
| Phase 1B | sonnet | phase1b-variant-generation.md | 選定プロセス+バリアント一覧（セクション2個） | 1 |
| Phase 2 | sonnet | phase2-test-document.md | 問題サマリ（セクション3個: 文書サマリ+埋込問題一覧+ボーナス問題） | 1 |
| Phase 3 | sonnet | （テンプレートなし、直接指示） | 1行（保存完了パス） | (プロンプト数)×2回 = 通常6-8並列 |
| Phase 4 | sonnet | phase4-scoring.md | 2行（スコアサマリ: Mean/SD+Run詳細） | プロンプト数 = 通常3-4並列 |
| Phase 5 | sonnet | phase5-analysis-report.md | 7行（recommended, reason, convergence, scores, variants, deploy_info, user_summary） | 1 |
| Phase 6A | sonnet | phase6a-knowledge-update.md | 1行（更新完了+累計ラウンド数） | 1 |
| Phase 6B | sonnet | phase6b-proven-techniques-update.md | 1行（昇格件数 or 更新なし） | 1（Phase 6Aと並列実行） |
