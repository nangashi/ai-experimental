## 重大な問題

### C-1: 不可逆操作のガード欠落: バックアップ作成失敗時の続行 [ux]
- 対象: SKILL.md:Phase 2 Step 4
- 内容: バックアップ作成コマンド (`cp {agent_path} {agent_path}.backup-$(date +%Y%m%d-%H%M%S)`) の実行結果を検証せず、失敗時も改善適用を続行する。ディスク容量不足・権限エラー時にバックアップなしで元ファイルが上書きされ、データ損失リスクがある
- 推奨: バックアップ作成後、Bash で `test -f {backup_path} && echo 'OK' || echo 'FAILED'` を実行し、FAILED の場合は「バックアップ作成に失敗しました。続行しますか？」と AskUserQuestion で確認する
- impact: high, effort: low

## 改善提案

### I-1: Phase 1 並列サブエージェント指示のテンプレート外部化 [architecture]
- 対象: SKILL.md:lines 115-118
- 内容: 7行超のサブエージェント指示がインラインで記述されているが、テンプレートに外部化すべき。Phase 1 の Task プロンプトは複数行のフォーマット要求を含み、8行程度の指示ブロックになっている
- 推奨: 「Read template + follow instructions + path variables」パターンに統一することで、将来の指示変更時に SKILL.md のコンテキスト負荷を削減できる
- impact: medium, effort: medium

### I-2: 目的の明確性: 成果物の明示不足 [effectiveness]
- 対象: SKILL.md:Phase 3
- 内容: SKILL.md の「使い方」セクションが「エージェント定義ファイルを指定して監査」とのみ記載し、最終成果物が何であるか（監査結果ファイル、改善適用されたエージェント定義、完了サマリ）を明示していない。Phase 3 の出力サマリを見ることで推測可能だが、使い方セクションでの明示が望ましい
- 推奨: 「使い方」セクションに「**期待される成果物**: (1) .agent_audit/{agent_name}/audit-*.md（各次元の findings）、(2) .agent_audit/{agent_name}/audit-approved.md（承認済み指摘）、(3) 改善適用後のエージェント定義ファイル（バックアップ付き）、(4) 完了サマリと次ステップ推奨」を追記する
- impact: medium, effort: low

---
注: 改善提案を 5 件省略しました（合計 7 件中上位 2 件を表示）。省略された項目は次回実行で検出されます。
