### 安定性レビュー結果

#### 重大な問題
- [参照整合性: 外部参照パスが旧スキル名を使用]: [SKILL.md] [行64, 221] [`.claude/skills/agent_audit/group-classification.md`、`.claude/skills/agent_audit/templates/apply-improvements.md`] → [`.claude/skills/agent_audit_new/group-classification.md`、`.claude/skills/agent_audit_new/templates/apply-improvements.md` に修正する] [impact: high] [effort: low]
- [冪等性: Phase 1 findings ファイルの上書き動作が不明確]: [SKILL.md] [Phase 1セクション] [サブエージェントが `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` に Write する際、既存ファイルを上書きするのか追記するのか、再実行時の挙動が不明] → [Phase 1 の冒頭で「既存 findings ファイルが存在する場合は削除する」または「Write は既存ファイルを上書きする」と明示する] [impact: high] [effort: low]
- [条件分岐の完全性: Phase 2 Step 4 サブエージェント失敗時の処理が未定義]: [SKILL.md] [行226] [apply-improvements サブエージェントの返答が得られない場合の処理フローが記述されていない] → [「サブエージェント失敗時: エラーメッセージを出力し、バックアップパスを提示して終了する」を追加する] [impact: high] [effort: medium]
- [条件分岐の完全性: Phase 2 検証失敗時の処理が不完全]: [SKILL.md] [行235] [検証失敗時は警告を表示するが、Phase 3 で警告を再表示する処理が Phase 3 定義に存在しない] → [Phase 3 の冒頭に「検証フラグ {validation_failed} を確認し、失敗時は警告セクションを追加」する処理を明記する] [impact: medium] [effort: medium]
- [条件分岐の完全性: Phase 1 全失敗時の判定基準が曖昧]: [SKILL.md] [行129] [「全て失敗した場合」の判定が「findings ファイルが存在しない、または空」だが、「空」の定義が不明（0バイト？ヘッダのみ？Summary セクションなし？）] → [「空」を「0バイトまたは `## Summary` セクションが存在しない」と定義する] [impact: medium] [effort: low]

#### 改善提案
- [出力フォーマット決定性: Phase 1 サブエージェントへの返答指示にフィールド区切りが不明確]: [SKILL.md] [行118] [返答フォーマット `dim: {次元名}, critical: {N}, improvement: {M}, info: {K}` が1行なのか複数行なのか、区切り文字が `, ` なのか改行なのか不明] → [返答フォーマットを「4行形式（各行に1フィールド）: `dim: {次元名}\ncritical: {N}\nimprovement: {M}\ninfo: {K}`」と明示する] [impact: medium] [effort: low]
- [曖昧表現: 「ファイル全体の書き換えが必要な場合」の基準が不明]: [templates/apply-improvements.md] [行23] [「ファイル全体の書き換えが必要な場合のみ使用する」が曖昧（変更箇所数？変更行数の割合？セクション全削除？）] → [「変更が10箇所を超える場合、またはファイル構造を大幅に変更する場合のみ Write を使用する。それ以外は Edit を優先する」と具体化する] [impact: medium] [effort: low]
- [参照整合性: テンプレート変数の定義が不足]: [templates/apply-improvements.md] [行3-5] [`{approved_findings_path}` と `{agent_path}` は使用されているが、SKILL.md のパス変数リストに明示されていない（行223-224 で暗黙的に渡されている）] → [SKILL.md の Phase 0 または冒頭に「Phase 2 Step 4 で使用するパス変数」セクションを追加し、`{approved_findings_path}`, `{agent_path}` を定義する] [impact: low] [effort: low]
- [条件分岐の完全性: Phase 2 Step 2a のユーザー入力解析ルールが不明]: [SKILL.md] [行181] [ユーザーが "Other" でテキスト入力した場合の解析方法（どの入力を「修正内容」として扱うか、入力が不明確な場合の処理）が未定義] → [「"Other" 選択時は追加の AskUserQuestion で修正内容を確認する。入力が不明確な場合は「スキップ」として扱う」を追加する] [impact: medium] [effort: medium]
- [冪等性: バックアップファイルの重複生成]: [SKILL.md] [行217] [再実行時に `{agent_path}.backup-$(date +%Y%m%d-%H%M%S)` が複数生成される（最新バックアップの特定が困難）] → [「既存バックアップが存在する場合は削除してから新規作成する」または「シンボリックリンク `{agent_path}.backup-latest` を最新バックアップに張る」を追加する] [impact: low] [effort: medium]
- [参照整合性: Phase 1 エラーハンドリングでの件数抽出ロジックが複雑]: [SKILL.md] [行126] [「件数はファイル内の `## Summary` セクションから抽出する（抽出失敗時は findings ファイル内の `### {ID_PREFIX}-` ブロック数から推定する）」が2段階フォールバックだが、サブエージェント返答にも件数が含まれている（行118）。返答優先か、ファイル優先か不明] → [「サブエージェント返答の件数を優先し、返答が不完全な場合のみファイルから抽出する」と優先順位を明示する] [impact: low] [effort: low]
- [出力フォーマット決定性: Phase 3 の条件分岐による出力バリエーションが多い]: [SKILL.md] [行242-278] [Phase 2 スキップ時、Phase 2 実行時、critical スキップ時、次のステップ提案の4つの条件分岐があり、出力テンプレートが複雑] → [Phase 3 の出力を1つのテンプレートに統合し、各フィールドを条件により空文字列にする設計に変更する（テンプレートの一貫性向上）] [impact: low] [effort: medium]

#### 良い点
- [出力フォーマット決定性]: Phase 1, 2, 3 の各テキスト出力にフォーマット例が明示されており、出力の一貫性が保たれている
- [冪等性]: Phase 2 Step 4 でバックアップを作成してから改善を適用しており、失敗時のロールバック手順が提示されている
- [参照整合性]: SKILL.md で定義されたディレクトリ構造（`.agent_audit/{agent_name}/`）がスキルディレクトリ内に実在し、全てのサブエージェントが統一パターンで参照している
