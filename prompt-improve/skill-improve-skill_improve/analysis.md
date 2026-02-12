# スキル構造分析: skill_improve

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 238 | メインワークフロー定義（Phase 0-7の制御フロー） |
| quality-criteria.md | 44 | 全レビューアー共有の評価基準（4観点の定義） |
| templates/analyze-skill-structure.md | 72 | Phase 1: スキル構造分析テンプレート |
| templates/reviewer-stability.md | 76 | Phase 2: 指示品質・安定性レビューテンプレート |
| templates/reviewer-efficiency.md | 79 | Phase 2: 効率性・コンテキスト最適化レビューテンプレート |
| templates/reviewer-ux.md | 94 | Phase 2: UX・ワークフロー設計レビューテンプレート |
| templates/reviewer-architecture.md | 98 | Phase 2: アーキテクチャ・パターンレビューテンプレート |
| templates/consolidate-findings.md | 72 | Phase 4: フィードバック統合・改善計画生成テンプレート |
| templates/apply-improvements.md | 49 | Phase 5: 改善適用テンプレート |
| templates/verify-improvements.md | 71 | Phase 6: 改善検証テンプレート |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7
- 各フェーズの目的:
  - Phase 0: 初期化・スキル検出・実行モード選択（Standard/Fast）
  - Phase 1: スキル構造分析（サブエージェント委譲）
  - Phase 2: 4観点の並列レビュー（stability, efficiency, ux, architecture）
  - Phase 3: フィードバック統合・コンフリクト解決（親が直接処理）
  - Phase 4: 改善計画生成 + ユーザー承認（サブエージェント委譲）
  - Phase 5: 改善適用（サブエージェント委譲）
  - Phase 6: 軽量検証（サブエージェント委譲、最大1回の追加修正ループ）
  - Phase 7: 完了サマリ出力

- データフロー:
  - Phase 0 → `{work_dir}/file-list.txt` → Phase 1 → `{work_dir}/analysis.md` → Phase 2, 4, 6
  - Phase 2 → `{work_dir}/review-*.md` (4ファイル) → Phase 3 → `{work_dir}/findings.md` → Phase 4
  - Phase 4 → `{work_dir}/improvement-plan.md` → Phase 5, 6
  - Phase 6 → `{work_dir}/verification.md`
  - Phase 1-6 の各成果物はファイルに保存、サブエージェントはサマリのみ返答

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| なし | - | - | - |

全ファイルがスキルディレクトリ内（`{skill_path}` または `{skill_improve_path}`）で完結しています。

## D. コンテキスト予算分析
- SKILL.md 行数: 238行（目標250行以下に適合）
- テンプレートファイル数: 8個、平均行数: 76.4行
- サブエージェント委譲: あり（Phase 1, 2, 4, 5, 6 で使用）
  - 委譲パターン: "Read template + follow instructions + path variables" を一貫使用
  - 全サブエージェントがsonnetモデル、長文生成・判断処理に適切
- 親コンテキストに保持される情報:
  - スキルパス、スキル名、作業ディレクトリ、実行モード（Standard/Fast）
  - リトライカウンター（Phase 6 用）
  - サブエージェント返答サマリ（行数: 1～7行、詳細はファイルに保存）
  - Phase 3 のフィードバック分類結果（重大/改善/良い点の件数と内容）
- 3ホップパターンの有無: なし（Phase 1-6 の全データ受け渡しがファイル経由）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | skill_path 未指定時の確認 | 共通（省略不可） |
| Phase 0 | AskUserQuestion | 実行モード選択（Standard/Fast） | 共通（省略不可） |
| Phase 1 | AskUserQuestion | Phase 1 失敗時のリトライ確認 | 共通 |
| Phase 2 | AskUserQuestion | レビュー成功数 ≤2 の場合の続行確認 | 共通 |
| Phase 3 | AskUserQuestion | コンフリクト未解決時のトレードオフ選択 | Fast: コンフリクト時のみ、Standard: 全分類結果を先に出力 |
| Phase 4 | AskUserQuestion | Phase 4 失敗時のリトライ確認 | 共通 |
| Phase 4 | AskUserQuestion | 改善計画の承認（全承認/修正要望/キャンセル） | 共通（Fast mode でも省略不可） |
| Phase 4 | AskUserQuestion | 修正要望の入力受け取り（修正要望選択時のみ） | 共通 |
| Phase 5 | AskUserQuestion | Phase 5 失敗時のリトライ確認 | 共通 |
| Phase 6 | AskUserQuestion | Phase 6 失敗時のリトライ確認 | 共通 |
| Phase 6 | AskUserQuestion | NEEDS_ATTENTION 時の対応選択（retry_count=0 のみ） | 共通 |
| Phase 6 | AskUserQuestion | 追加修正の方針入力（追加修正選択時のみ） | 共通 |

Fast mode の差分:
- Phase 3: 全フィードバック詳細の出力をスキップ（サマリのみ表示）
- その他のユーザー確認は Standard/Fast で共通

## F. エラーハンドリングパターン
- ファイル不在時:
  - SKILL.md 不在: エラー出力して終了
  - .md ファイル 0件: エラー出力して終了
  - Phase 5: 対象ファイル Read 失敗時は skipped リストに追加、継続実行
- サブエージェント失敗時:
  - Phase 1, 4, 5, 6: AskUserQuestion で「リトライ」/「中止」を確認
  - Phase 2: 成功数 ≥3 なら続行、≤2 なら AskUserQuestion で「続行」/「中止」を確認
- 部分完了時:
  - Phase 2: 成功数と失敗レビューアー名をテキスト出力、成功数 ≥3 なら続行
  - Phase 5: 二重適用チェックで変更スキップ時は skipped リストに記録し継続
- 入力バリデーション:
  - skill_path 未指定: AskUserQuestion で確認
  - SKILL.md 不在: エラー出力して終了
  - Phase 6 NEEDS_ATTENTION: retry_count で再試行上限（1回）を制御

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | analyze-skill-structure.md | 4行（files, lines, phases, external_refs, checkpoints） | 1 |
| Phase 2 | sonnet | reviewer-stability.md | 1行（critical, improvement, positive の件数） | 4（並列） |
| Phase 2 | sonnet | reviewer-efficiency.md | 1行（critical, improvement, positive の件数） | 4（並列） |
| Phase 2 | sonnet | reviewer-ux.md | 1行（critical, improvement, positive の件数） | 4（並列） |
| Phase 2 | sonnet | reviewer-architecture.md | 1行（critical, improvement, positive の件数） | 4（並列） |
| Phase 4 | sonnet | consolidate-findings.md | 4行（modified, created, deleted_recommended, total_findings_addressed） | 1 |
| Phase 5 | sonnet | apply-improvements.md | 可変行数（modified, created, skipped, delete_recommended の件数+詳細） | 1 |
| Phase 6 | sonnet | verify-improvements.md | 6行（resolved, partial, not_addressed, new_issues, verdict, details） | 1 |
