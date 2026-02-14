# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 279 | メインスキル定義: ワークフロー、グループ分類、並列分析 |
| agents/evaluator/criteria-effectiveness.md | 112 | サブエージェント定義: 評価基準の有効性分析 (CE次元) |
| agents/evaluator/scope-alignment.md | 123 | サブエージェント定義: レビューアのスコープ整合性分析 (SA次元) |
| agents/evaluator/detection-coverage.md | 106 | サブエージェント定義: 検出カバレッジ分析 (DC次元) |
| group-classification.md | 22 | 参照ドキュメント: エージェントグループ分類基準 |
| agents/producer/workflow-completeness.md | 109 | サブエージェント定義: ワークフロー完全性分析 (WC次元) |
| agents/producer/output-format.md | 97 | サブエージェント定義: 出力形式実現性分析 (OF次元) |
| agents/unclassified/scope-alignment.md | 91 | サブエージェント定義: 汎用スコープ整合性分析 (SA次元・軽量版) |
| agents/shared/instruction-clarity.md | 89 | サブエージェント定義: 指示明確性分析 (IC次元・共通) |
| templates/apply-improvements.md | 38 | サブエージェント用テンプレート: 承認済み改善の適用 |

## B. ワークフロー概要
- フェーズ構成: Phase 0 (初期化・グループ分類) → Phase 1 (並列分析) → Phase 2 (ユーザー承認 + 改善適用) → Phase 3 (完了サマリ)
- 各フェーズの目的:
  - Phase 0: エージェント定義ファイルを読み込み、内容からグループ (hybrid/evaluator/producer/unclassified) を判定し、分析次元セットを決定する
  - Phase 1: グループに応じた3〜5次元のサブエージェントを並列起動し、各次元の静的分析を実行する
  - Phase 2: 検出した findings を一覧提示し、ユーザー承認を得て改善をエージェント定義ファイルに適用する
  - Phase 3: 分析・改善結果のサマリを出力し、次のステップ (再監査 or agent_bench) を提示する
- データフロー:
  - Phase 0: `{agent_path}` (入力) → `{agent_content}` (メモリ保持) → `{agent_group}` (判定結果) → `.agent_audit/{agent_name}/` (ディレクトリ作成)
  - Phase 1: 各サブエージェント → `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` (findings 保存)
  - Phase 2 Step 1-2: Phase 1 で生成された audit-*.md ファイルを Read → 一覧提示 → ユーザー入力
  - Phase 2 Step 3: 承認結果 → `.agent_audit/{agent_name}/audit-approved.md` (Write)
  - Phase 2 Step 4: `audit-approved.md` + `{agent_path}` → `templates/apply-improvements.md` サブエージェント → `{agent_path}` 更新 (Edit/Write)
  - Phase 3: Phase 1-2 のメタデータを集約してサマリ出力

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 64 | `.claude/skills/agent_audit/group-classification.md` | グループ分類基準の参照先 (実際は `agent_audit_new/group-classification.md` のはず) |
| SKILL.md | 221 | `.claude/skills/agent_audit/templates/apply-improvements.md` | 改善適用テンプレート (実際は `agent_audit_new/templates/apply-improvements.md` のはず) |

**注**: SKILL.md 内の参照パスが `/agent_audit/` (旧スキル名) になっており、現在のスキルディレクトリ `/agent_audit_new/` と不一致。実行時にファイルが見つからないエラーが発生する可能性が高い。

## D. コンテキスト予算分析
- SKILL.md 行数: 279行
- テンプレートファイル数: 1個、平均行数: 38行
- サブエージェント委譲: あり（Phase 1 で最大5並列 + Phase 2 Step 4 で1シーケンシャル）
- 親コンテキストに保持される情報:
  - `{agent_content}`: エージェント定義ファイル全文 (Phase 0 で Read、Phase 2 検証で再 Read)
  - `{agent_group}`: グループ判定結果 (4値: hybrid/evaluator/producer/unclassified)
  - `{agent_name}`, `{dim_count}`, dimensions リスト: メタデータ
  - Phase 1 サブエージェント返答サマリ: 各次元の critical/improvement/info 件数 (最大5次元 × 1行 = 5行)
  - Phase 2 findings 抽出結果: critical + improvement findings のリスト (可変長、対象件数が多い場合コンテキスト肥大化のリスク)
  - Phase 2 承認結果: 承認/スキップ/修正内容 (可変長)
- 3ホップパターンの有無: なし
  - Phase 1 サブエージェント → findings ファイル → Phase 2 Step 1 Read (ファイル経由の2ホップ)
  - Phase 2 Step 3 Write → audit-approved.md → Phase 2 Step 4 サブエージェント (ファイル経由の2ホップ)

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | 引数 `agent_path` が未指定の場合にファイルパスを確認 | 不明 |
| Phase 2 Step 2 | AskUserQuestion | 承認方針の選択 (全て承認 / 1件ずつ確認 / キャンセル) | 不明 (Fast mode 記載なし) |
| Phase 2 Step 2a | AskUserQuestion | Per-item 承認ループ (承認 / スキップ / 残りすべて承認 / キャンセル) | 不明 (Fast mode 記載なし) |

**注**: SKILL.md には Fast mode への言及がないため、中間確認スキップの実装は未対応と推測される。

## F. エラーハンドリングパターン
- ファイル不在時:
  - Phase 0 Step 2: Read 失敗時はエラー出力して終了
  - Phase 1: findings ファイルが存在しない場合は「分析失敗」として扱い、エラー概要を抽出。全次元失敗の場合はエラー出力して終了
  - Phase 2 検証ステップ: YAML frontmatter 検証失敗時は警告を出力し、ロールバックコマンドを提示
- サブエージェント失敗時:
  - Phase 1: findings ファイルの存在確認で成否判定。失敗時は Task 返答からエラーメッセージを抽出し、該当次元は「分析失敗」として扱う (処理は継続)
  - Phase 2 Step 4: サブエージェントの返答内容を出力するが、失敗時のリトライ・ロールバックは未定義
- 部分完了時:
  - Phase 1: 一部次元が失敗しても成功した次元の結果を使用して Phase 2 へ進む
  - Phase 2 Step 2a: ユーザーが「キャンセル」選択時は Phase 3 へ直行
  - Phase 2 Step 3: 承認数が 0 の場合は改善適用をスキップして Phase 3 へ直行
- 入力バリデーション:
  - Phase 0 Step 3: YAML frontmatter の簡易チェック。存在しない場合は警告を出力するが処理は継続
  - Phase 2 適用ルール: 二重適用チェックあり (Edit 前に対象箇所の内容が findings の前提と一致するか確認)

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | `agents/{dim_path}.md` (IC, CE, SA, DC, WC, OF の最大5次元) | 4行 (`dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`) | 3〜5 (グループにより変動) |
| Phase 2 Step 4 | sonnet | `templates/apply-improvements.md` | 可変長 (modified + skipped のサマリ) | 1 |

**注**: Phase 1 の並列数はグループによって異なる:
- hybrid: 5並列 (IC, CE, SA, WC, OF)
- evaluator: 4並列 (IC, CE, SA, DC)
- producer: 4並列 (IC, WC, OF, SA-軽量版)
- unclassified: 3並列 (IC, SA-軽量版, WC)
