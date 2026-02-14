### 安定性レビュー結果

#### 重大な問題
- [参照整合性: 外部ファイルパスの不整合]: [SKILL.md] [全フェーズで参照するパスが `.claude/skills/agent_bench/` を指しているが、実際のスキルディレクトリは `.claude/skills/agent_bench_new/` である] → [全ての `.claude/skills/agent_bench/` を `.claude/skills/agent_bench_new/` に置換する] [impact: high] [effort: low]
- [冪等性: knowledge.md 更新の累積リスク]: [templates/phase6a-knowledge-update.md] [行16-22] [「既存の原則を全て保持する（削除しない）」と「20行を超える場合は…統合または削除する」が並立しており、何回も実行すると削除基準が曖昧] → [削除基準を明確化: 「20行を超える場合は、effect pt が最小かつ SD が最大の原則から優先的に統合/削除する。統合は同一カテゴリ内の2原則をマージする」と具体化] [impact: medium] [effort: low]
- [条件分岐の不完全性: Phase 3 エラーハンドリング]: [SKILL.md] [行229-236] [「各プロンプトに最低1回の成功結果がある」場合と「成功結果が0回」の分岐はあるが、「ベースラインが失敗したが一部バリアントは成功」のケースの明示的な処理がない] → [ベースライン失敗時の分岐を追加: 「ベースラインの成功結果が0回の場合: AskUserQuestion で (1)ベースライン再試行、(2)該当ラウンドを中断してエージェント定義を修正、(3)スキルを終了、から選択させる」] [impact: high] [effort: medium]
- [参照整合性: 未定義のパス変数]: [templates/phase1b-variant-generation.md] [行8-9] [`{audit_dim1_path}` と `{audit_dim2_path}` がテンプレートで言及されているが、SKILL.md の Phase 1B のパス変数リストでは `{audit_findings_paths}` というカンマ区切りの1変数として定義されている] → [SKILL.md 174行を修正: 「`{audit_findings_paths}` として渡す」を削除し、「`{audit_ce_path}`: audit-ce-*.md の検出結果（見つからない場合は空文字列）、`{audit_sa_path}`: audit-sa-*.md の検出結果（見つからない場合は空文字列）」に変更。テンプレート側も対応する変数名に修正」] [impact: high] [effort: medium]
- [出力フォーマット決定性: Phase 6 サマリ行数が未保証]: [SKILL.md] [行356-371] [最終サマリのフォーマットは明示されているが、knowledge.md に「効果のあったテクニック: {knowledge.md の上位項目}」とあり、上位項目の件数が定義されていない] → [「効果のあったテクニック: {knowledge.md の効果確認テーブルから上位3件、形式: テクニック名(+効果pt)}」と具体化] [impact: medium] [effort: low]

#### 改善提案
- [曖昧表現: 「最初に見つかったファイル」]: [SKILL.md] [行74-76] [「最初に見つかったファイルを `{reference_perspective_path}` として使用」と記載されているが、Glob の並び順がファイルシステムに依存し、実行ごとに異なる可能性がある] [impact: low] [effort: low]
- [冪等性: perspective 自動生成の重複実行]: [SKILL.md] [Phase 0 Step 3-6] [perspective-source.md が既に存在する場合でも Step 3-6 を実行すると上書きされる。Phase 0 の「パースペクティブの解決」で既存ファイル検出時に自動生成をスキップする条件が不明確] → [Step 4a の前に「`.agent_bench/{agent_name}/perspective-source.md` が既に存在する場合は Step 3-6 をスキップする」を明記] [impact: medium] [effort: low]
- [曖昧表現: 「自然に埋め込む」]: [test-document-guide.md] [行155] [「問題はわざとらしくならないよう自然に埋め込む」という指示は抽象的で、AIごとに解釈が異なる可能性がある] [impact: low] [effort: medium]
- [出力フォーマット決定性: Phase 1A サマリの構造]: [templates/phase1a-variant-generation.md] [行22-40] [「以下のフォーマットで結果サマリのみ返答する」と指示しているが、構造分析テーブルの行数やバリアント数が明示されていない] [impact: low] [effort: low]
- [条件分岐の不完全性: Phase 4 ベースライン失敗の詳細処理]: [SKILL.md] [行263] [「ベースラインが失敗した場合は中断」とあるが、中断時のメッセージ内容やエラー処理が不明確] → [「ベースラインの採点が失敗した場合: エラー内容を出力し、AskUserQuestion で (1)再試行、(2)該当ラウンドを中断してエージェント定義を修正、(3)スキルを終了、から選択させる」と具体化] [impact: medium] [effort: medium]
- [参照整合性: テンプレート内の出力先変数の未定義]: [templates/perspective/generate-perspective.md] [行60] [「Write で `{perspective_save_path}` に保存する」とあるが、このテンプレート自体はサブエージェントへの指示であり、サブエージェントが保存するファイルパスを親が変数として渡す設計になっている。しかし、SKILL.md 81-86行のパス変数リストには `{perspective_save_path}` が定義されているため問題ない] [impact: low] [effort: low]
- [曖昧表現: 「判断に迷う場合」]: [scoring-rubric.md] [行37] [「判断に迷う場合はペナルティを付与しない」という原則は一般的すぎる。perspective.md のボーナス/ペナルティ判定指針に委譲しているが、指針が不明確な場合の動作が定義されていない] [impact: low] [effort: medium]

#### 良い点
- パス変数とテンプレートパターンが一貫して使用されており、サブエージェント委譲の設計が明確
- Phase 3 の並列実行後のエラーハンドリング分岐（成功数による3分岐）が詳細に定義されている
- knowledge.md 更新とproven-techniques.md 更新が「まず A を実行し完了を待つ → 次に B, C を並列実行」のように依存関係が明示されている
