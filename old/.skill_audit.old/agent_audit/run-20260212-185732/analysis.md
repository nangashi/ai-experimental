# スキル構造分析: agent_audit

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 254 | メインスキル定義。グループ分類、ワークフロー制御、Phase 0-3 の実行ロジック |
| templates/apply-improvements.md | 32 | Phase 2 Step 4 のサブエージェントテンプレート。承認済み findings に基づくエージェント定義の改善適用 |
| agents/evaluator/criteria-effectiveness.md | 92 | evaluator/hybrid グループの分析次元。評価基準の有効性（曖昧さ、S/N比、実行可能性、費用対効果、カバレッジギャップ）を分析 |
| agents/shared/instruction-clarity.md | 94 | 全グループ共通の分析次元。指示の明確性、コンテキスト充足性、プロンプトエンジニアリング品質、情報構造を分析 |
| agents/evaluator/scope-alignment.md | 102 | evaluator/hybrid グループの分析次元。レビュアー型エージェントのスコープ定義、境界明確性、内部整合性を分析 |
| agents/evaluator/detection-coverage.md | 106 | evaluator グループの分析次元。検出戦略、severity 分類、出力形式、偽陽性リスク、敵対的堅牢性を分析 |
| agents/producer/workflow-completeness.md | 106 | producer/hybrid/unclassified グループの分析次元。ワークフローのステップ順序、エラー処理、入出力完全性、エッジケース対応を分析 |
| agents/producer/output-format.md | 98 | producer/hybrid グループの分析次元。出力形式の実現可能性、下流利用可能性、情報完全性、セクション間整合性を分析 |
| agents/unclassified/scope-alignment.md | 89 | producer/unclassified グループの分析次元。一般エージェントの目的明確性、フォーカス適切性、境界暗黙性を分析（軽量版） |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → Phase 1 → Phase 2 → Phase 3
- 各フェーズの目的:
  - **Phase 0**: エージェント定義ファイルの読み込み、グループ分類（hybrid/evaluator/producer/unclassified）、分析次元セットの決定、出力ディレクトリ作成
  - **Phase 1**: グループに応じた分析次元（3-5個）のサブエージェントを並列起動し、各次元で findings を生成
  - **Phase 2**: Phase 1 で検出された critical/improvement findings をユーザーに提示し、承認/スキップを選択。承認された findings をサブエージェントが適用
  - **Phase 3**: 分析結果サマリ（検出件数、承認件数、変更ファイル）と次ステップ提案を出力
- データフロー:
  - Phase 0: 入力 `{agent_path}` → 出力 `{agent_content}`, `{agent_group}`, `{agent_name}`, `.agent_audit/{agent_name}/` ディレクトリ
  - Phase 1: 入力 `{agent_path}`, `{agent_name}` → 出力 `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` (各次元)
  - Phase 2: 入力 `.agent_audit/{agent_name}/audit-*.md` → 出力 `.agent_audit/{agent_name}/audit-approved.md` → サブエージェントが `{agent_path}` を直接編集
  - Phase 3: Phase 1, 2 の結果をサマリ化してテキスト出力

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 97-104 | `.claude/skills/agent_audit/agents/{dim_path}.md` | Phase 1 でのサブエージェントへの分析次元ファイルパス指定 |
| SKILL.md | 229 | `.claude/skills/agent_audit/templates/apply-improvements.md` | Phase 2 Step 4 でのサブエージェント改善適用テンプレート |
| SKILL.md | 252 | `/agent_bench {agent_path}` | Phase 3 の次ステップ提案（agent_bench スキルへの言及） |

**補足**: `agents/` および `templates/` ディレクトリはスキル内部のサブディレクトリであり、外部参照ではないが、サブエージェントへのパス指定として機能している。agent_bench スキルへの言及はテキスト出力のみで実際の依存はない。

## D. コンテキスト予算分析
- SKILL.md 行数: 254行
- テンプレートファイル数: 1個、行数: 32行
- サブエージェント委譲: あり（Phase 1 で 3-5個の並列分析サブエージェント、Phase 2 Step 4 で改善適用サブエージェント 1個）
- 親コンテキストに保持される情報:
  - `{agent_content}` (エージェント定義の全テキスト)
  - `{agent_group}` (分類結果: hybrid/evaluator/producer/unclassified)
  - `{agent_name}` (導出されたエージェント名)
  - `{dim_count}` (分析次元数)
  - Phase 1 各サブエージェントの返答サマリ（4行: dim, critical, improvement, info の件数）
  - Phase 2 承認結果（承認数、スキップ数）
  - Phase 2 Step 4 サブエージェントの返答（変更サマリ: modified, skipped）
- 3ホップパターンの有無: なし
  - Phase 1 のサブエージェントは findings をファイルに保存し、親は件数サマリのみ受け取る
  - Phase 2 のサブエージェントは `.agent_audit/{agent_name}/audit-approved.md` を直接読み込んで改善を適用し、変更サマリのみ返す
  - すべてファイル経由のデータ受け渡しで、親が中継する3ホップパターンは存在しない

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | `agent_path` 未指定時のパス確認 | 不明（fast mode 言及なし） |
| Phase 2 Step 2 | AskUserQuestion | 承認方針の選択（全て承認 / 1件ずつ確認 / キャンセル） | 不明（fast mode 言及なし） |
| Phase 2 Step 2a | AskUserQuestion | Per-item 承認（承認 / スキップ / 残りすべて承認 / キャンセル）× findings 件数 | 不明（fast mode 言及なし） |

**補足**: Phase 2 の承認フローは必須のユーザーインタラクション。「全て承認」を選択すればループをスキップできるが、完全な自動実行モードは存在しない。

## F. エラーハンドリングパターン
- ファイル不在時:
  - Phase 0: `agent_path` の Read 失敗時、エラー出力して終了
  - Phase 1: 各サブエージェントの findings ファイルが存在しない場合、該当次元を「分析失敗」として扱う
  - Phase 1: 全次元が失敗した場合、エラー出力して終了
- サブエージェント失敗時:
  - Phase 1: 返答フォーマットが期待形式（4行: dim, critical, improvement, info）に一致しない、または findings ファイルが存在しない場合、該当次元を「分析失敗」として記録。残りの成功次元で継続
  - Phase 2 Step 4: サブエージェント返答が期待形式（modified, skipped）に一致しない場合の明示的処理は未定義（返答内容をそのままテキスト出力）
- 部分完了時:
  - Phase 1: 1つ以上の次元が成功すれば継続（成功数/総数を表示）
  - Phase 2: 承認数が 0 の場合、改善適用をスキップして Phase 3 へ進む
- 入力バリデーション:
  - Phase 0: ファイル先頭の YAML frontmatter（`---` で囲まれ `description:` を含む）の存在チェック。存在しない場合は警告テキスト出力するが処理は継続
  - Phase 0: `agent_path` 未指定時のみ AskUserQuestion で確認（それ以外のバリデーションなし）

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | agents/shared/instruction-clarity.md | 4行 | 全グループで1個 |
| Phase 1 | sonnet | agents/evaluator/criteria-effectiveness.md | 4行 | hybrid/evaluator で1個 |
| Phase 1 | sonnet | agents/evaluator/scope-alignment.md | 4行 | hybrid/evaluator で1個 |
| Phase 1 | sonnet | agents/evaluator/detection-coverage.md | 4行 | evaluator のみで1個 |
| Phase 1 | sonnet | agents/producer/workflow-completeness.md | 4行 | hybrid/producer/unclassified で1個 |
| Phase 1 | sonnet | agents/producer/output-format.md | 4行 | hybrid/producer で1個 |
| Phase 1 | sonnet | agents/unclassified/scope-alignment.md | 4行 | producer/unclassified で1個 |
| Phase 2 Step 4 | sonnet | templates/apply-improvements.md | 2-4行（modified, skipped） | 1個 |

**補足**: Phase 1 の並列数はグループにより異なる。hybrid: 5個、evaluator: 4個、producer: 4個、unclassified: 3個。
