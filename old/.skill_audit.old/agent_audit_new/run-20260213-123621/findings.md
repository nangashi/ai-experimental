## 重大な問題

### C-1: Phase 0 frontmatter検証失敗時の処理フロー不足 [stability]
- 対象: SKILL.md:69
- 内容: frontmatter が存在しない場合、警告を出力するが「処理は継続する」と明記。しかし、その後のグループ分類処理では frontmatter の description フィールドを参照する前提がない。エージェント定義でない場合のグループ分類の動作が未定義
- 推奨: Step 3 で frontmatter が存在しない場合の処理を明示する: (1) グループ分類処理をスキップして unclassified とする、(2) AskUserQuestion で継続/中止を確認する、のいずれかを採用し、以降のフローに明示的な分岐を追加する
- impact: high, effort: medium

### C-2: Phase 1 全次元失敗時の処理フロー不明確 [stability]
- 対象: SKILL.md:152
- 内容: 全次元失敗時にエラー出力して終了するが、Phase 2 へのスキップ処理や、Phase 3 での失敗サマリ出力との整合性が不明確。全失敗は完了サマリを出力せずに終了するのか、Phase 3 で失敗状況を報告するのかが未定義
- 推奨: 全次元失敗時の処理を明示する: 「エラー出力して終了する（Phase 3 はスキップ）」または「Phase 3 へ進み、全失敗サマリを出力する」のいずれかを選択し、フローに明記する
- impact: high, effort: medium

### C-3: テンプレート内の未定義プレースホルダ [stability]
- 対象: templates/apply-improvements.md:22
- 内容: {agent_path} プレースホルダは、SKILL.md のパス変数リストで定義されているが、手順1で Read によって読み込まれた内容を指しているのか、ファイルパス文字列を指しているのかが不明瞭。保持した内容を使用する指示と、変数名が衝突している
- 推奨: プレースホルダ名を {agent_content} に変更し、SKILL.md のパス変数リストに {agent_content} を追加する。または、テンプレート内の記述を「手順1で Read した {agent_path} の内容を保持し」に明確化する
- impact: medium, effort: low

### C-4: Phase 2 承認結果ファイルの上書きリスク [stability]
- 対象: SKILL.md:213
- 内容: `.agent_audit/{agent_name}/audit-approved.md` に Write で保存するが、再実行時の既存ファイル確認や上書き警告がない。前回の承認結果が上書きされる
- 推奨: Step 3 の前に Read で既存の audit-approved.md を確認し、存在する場合は AskUserQuestion で上書き確認を行うか、タイムスタンプ付きファイル名 (`audit-approved-{timestamp}.md`) に変更する
- impact: medium, effort: medium

### C-5: バックアップファイル名の重複可能性 [stability]
- 対象: SKILL.md:239
- 内容: バックアップファイル名に `$(date +%Y%m%d-%H%M%S)` を使用しているが、同一分内に複数回実行すると同じバックアップファイル名になり上書きされる可能性がある。また、バックアップファイルの累積管理（古いバックアップの削除）についての記述がない
- 推奨: バックアップファイル名にミリ秒を含めるか、ファイル存在確認を行い既存の場合は `-2`, `-3` のような連番を付与する。また、バックアップの保持期間や削除方針を SKILL.md に記述する
- impact: medium, effort: low

## 改善提案

### I-1: Phase 0 グループ分類ロジックの外部化 [architecture]
- 対象: SKILL.md:73-92
- 内容: エージェント分類ロジック（evaluator/producer特徴判定+判定ルール）が20行のインラインロジックとして記述されている。テンプレートファイル `templates/classify-agent-group.md` への外部化を推奨
- 推奨: テンプレートファイル `templates/classify-agent-group.md` への外部化（パス変数: agent_content, agent_name）
- impact: medium, effort: low

### I-2: Phase 2 Step 2a 承認ループのテンプレート外部化 [architecture]
- 対象: SKILL.md:190-207
- 内容: per-item承認ループの指示が18行のインラインブロックとして記述されている。テンプレートファイル `templates/per-item-approval.md` への外部化を推奨
- 推奨: テンプレートファイル `templates/per-item-approval.md` への外部化（パス変数: findings_list, total, approved_findings_path）
- impact: medium, effort: low

### I-3: apply-improvements 二重適用チェック実装の補強 [architecture]
- 対象: templates/apply-improvements.md:21
- 内容: 二重適用チェックで「手順1で Read した {agent_path} の内容を保持し、適用時の二重適用チェックではその保持内容を使用する」と記述があるが、複数 findings が同一箇所に影響する場合の検証手順が明示されていない。変更適用後の内容を保持変数に反映するステップを追加推奨
- 推奨: 変更適用後の内容を保持変数に反映するステップを追加する
- impact: medium, effort: low

### I-4: agent_content の Phase 2 での再利用が暗黙的 [effectiveness]
- 対象: Phase 0 Step 2 → Phase 2 検証ステップ
- 内容: Phase 0 で読み込んだ `{agent_content}` が Phase 1 のグループ分類で使用されるが、その後 Phase 2 の検証ステップで再度必要となる構造が暗黙的である。SKILL.md には「Phase 0 で Read し `{agent_content}` として保持する」とあるが、Phase 2 検証ステップでの再利用が明記されていない。Phase 1 完了後に破棄されるのか、Phase 2 まで保持されるのかが不明確
- 推奨: Phase 0 で agent_content の保持範囲を明示する（Phase 2 検証ステップまで保持することを記述）
- impact: medium, effort: low

---
注: 改善提案を 13 件省略しました（合計 17 件中上位 4 件を表示）。省略された項目は次回実行で検出されます。
