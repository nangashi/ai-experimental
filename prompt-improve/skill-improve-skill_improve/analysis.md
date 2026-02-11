# スキル構造分析: skill_improve

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 221 | メインワークフロー定義（Phase 0-7） |
| quality-criteria.md | 42 | 4つの品質観点の評価基準定義 |
| templates/analyze-skill-structure.md | 71 | Phase 1: スキル構造分析サブエージェント指示 |
| templates/consolidate-findings.md | 69 | Phase 4: 改善計画生成サブエージェント指示 |
| templates/apply-improvements.md | 49 | Phase 5: 改善適用サブエージェント指示 |
| templates/verify-improvements.md | 71 | Phase 6: 検証サブエージェント指示 |
| templates/reviewer-stability.md | 76 | Phase 2: 安定性レビューアー指示 |
| templates/reviewer-efficiency.md | 79 | Phase 2: 効率性レビューアー指示 |
| templates/reviewer-ux.md | 91 | Phase 2: UXレビューアー指示 |
| templates/reviewer-architecture.md | 98 | Phase 2: アーキテクチャレビューアー指示 |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7
- 各フェーズの目的:
  - Phase 0: スキルパスの初期化・検証、自己改善検出、実行モード選択（Standard/Fast）
  - Phase 1: スキル構造分析（サブエージェント委譲、analysis.md 生成）
  - Phase 2: 4つの観点（stability, efficiency, ux, architecture）で並列レビュー（各 review-*.md 生成）
  - Phase 3: フィードバック分類（重大/改善/良い点）・コンフリクト検出・解決・findings.md 生成
  - Phase 4: 改善計画生成（サブエージェント委譲、improvement-plan.md 生成）+ ユーザー承認
  - Phase 5: 改善適用（サブエージェント委譲、Edit/Write によるファイル修正）
  - Phase 6: 軽量検証（サブエージェント委譲、verification.md 生成）+ 再試行判定
  - Phase 7: 完了サマリ出力

- データフロー:
  - Phase 1 生成: analysis.md → Phase 2（全レビューアー）, Phase 4, Phase 6 が参照
  - Phase 2 生成: review-stability.md, review-efficiency.md, review-ux.md, review-architecture.md（4件）→ Phase 3 が読み込み
  - Phase 3 生成: findings.md → Phase 4, Phase 6 が参照
  - Phase 4 生成: improvement-plan.md → Phase 5, Phase 6 が参照
  - Phase 5: スキルファイル修正 → Phase 6 が検証
  - Phase 6 生成: verification.md → Phase 7 で参照（サマリ出力）

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| なし | - | - | - |

全ての参照（SKILL.md: 55行目「.claude/skills/skill_improve/templates/analyze-skill-structure.md」、91行目「.claude/skills/skill_improve/quality-criteria.md」等）はスキルディレクトリ内の相対パス。外部参照なし。

## D. コンテキスト予算分析
- SKILL.md 行数: 221行（目標 ≤250行: 達成）
- テンプレートファイル数: 10個、平均行数: 72.5行
- サブエージェント委譲: あり（Phase 1, 2, 4, 5, 6 で委譲）
  - Phase 1: 1件（sonnet、構造分析、5行返答）
  - Phase 2: 4件並列（各 sonnet、4観点レビュー、各1行返答）
  - Phase 4: 1件（sonnet、改善計画生成、4行返答）
  - Phase 5: 1件（sonnet、改善適用、可変行返答）
  - Phase 6: 1件（sonnet、検証、5行返答）
  - 全サブエージェントが「Read template + follow instructions + path variables」パターンを使用
- 親コンテキストに保持される情報:
  - 変数: skill_path, skill_name, work_dir, file_list, retry_count
  - サブエージェント返答サマリ（5-10行程度のメタデータのみ）
  - Phase 3 で分類したフィードバック（Standard mode でテキスト出力、詳細は findings.md に保存）
  - Phase 4 で読み込んだ improvement-plan.md の全文（ユーザー承認のため必須）
- 3ホップパターンの有無: なし
  - 全てのサブエージェント間データ受け渡しはファイル経由（analysis.md → review-*.md → findings.md → improvement-plan.md → verification.md）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | skill_path が未指定の場合の確認 | 共通（省略不可） |
| Phase 0 | AskUserQuestion | 実行モード選択（Standard/Fast） | 共通（省略不可） |
| Phase 1 | AskUserQuestion | Task 失敗時「リトライ/中止」 | 共通（失敗時のみ） |
| Phase 2 | AskUserQuestion | レビュー成功数 ≤2 の場合「続行/中止」 | 共通（失敗時のみ） |
| Phase 3 | AskUserQuestion | コンフリクト未解決時のユーザー判定 | Fast mode でも表示（未解決時のみ） |
| Phase 4 | AskUserQuestion | Task 失敗時「リトライ/中止」 | 共通（失敗時のみ） |
| Phase 4 | AskUserQuestion | 改善計画の承認「全て承認/修正要望あり/キャンセル」 | Fast mode でも省略不可 |
| Phase 5 | AskUserQuestion | Task 失敗時「リトライ/中止」 | 共通（失敗時のみ） |
| Phase 6 | AskUserQuestion | Task 失敗時「リトライ/中止」 | 共通（失敗時のみ） |
| Phase 6 | AskUserQuestion | verdict: NEEDS_ATTENTION 時「受け入れる/追加修正/取り消す」 | 共通（警告時のみ） |

Standard mode vs Fast mode:
- Standard mode: Phase 3 で全分類結果（重大/改善/良い点の詳細）をテキスト出力
- Fast mode: Phase 3 でサマリのみ出力（「検出: 重大 {N}件, 改善 {M}件, 良い点 {K}件」）

## F. エラーハンドリングパターン
- ファイル不在時:
  - Phase 0: SKILL.md 不在の場合、エラーメッセージ出力して終了
  - Phase 0: Glob で .md ファイル0件の場合、エラーメッセージ出力して終了
  - Phase 3 (analyze-skill-structure.md テンプレート内): Read できなかったファイルは「未読」と記載（25行目）
- サブエージェント失敗時:
  - Phase 1, 4, 5, 6: Task 失敗時、エラー内容をテキスト出力し、AskUserQuestion で「リトライ/中止」をユーザーに確認
  - Phase 2: 4件の Task 完了後、成功数を判定。成功数 ≥3: 続行、成功数 ≤2: AskUserQuestion で「続行/中止」確認
- 部分完了時:
  - Phase 2: 成功数が4未満の場合、失敗したレビューアー名をテキスト出力。成功数 ≥3 で「最低基準を満たしている」として Phase 3 へ進む
  - Phase 6: verification で verdict: NEEDS_ATTENTION 判定時、retry_count を確認。0回目: AskUserQuestion で対応選択、1回目: 検証結果出力して Phase 7 へ（再試行上限）
- 入力バリデーション:
  - Phase 0: skill_path の絶対パス変換、SKILL.md 存在確認、ファイルリスト確認
  - Phase 0: 自己改善検出（skill_path に「.claude/skills/skill_improve」が含まれる場合に警告出力）
  - Phase 3: 問題が0件（重大 + 改善 = 0）の場合、Phase 4-6 をスキップし Phase 7 へ直行

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | analyze-skill-structure.md | 5行（files, lines, phases, external_refs, checkpoints） | 1 |
| Phase 2 | sonnet | reviewer-stability.md | 1行（critical, improvement, positive） | 4（並列） |
| Phase 2 | sonnet | reviewer-efficiency.md | 1行（critical, improvement, positive） | 4（並列） |
| Phase 2 | sonnet | reviewer-ux.md | 1行（critical, improvement, positive） | 4（並列） |
| Phase 2 | sonnet | reviewer-architecture.md | 1行（critical, improvement, positive） | 4（並列） |
| Phase 4 | sonnet | consolidate-findings.md | 4行（modified, created, deleted_recommended, total_findings_addressed） | 1 |
| Phase 5 | sonnet | apply-improvements.md | 可変長（modified/created/skipped/delete_recommended 各セクション） | 1 |
| Phase 6 | sonnet | verify-improvements.md | 5行（resolved, partial, not_addressed, new_issues, verdict, details） | 1 |
