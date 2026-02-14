### 安定性レビュー結果

#### 重大な問題
- [参照整合性: perspective 批評のパス変数 {task_id} が未定義]: [templates/perspective/critic-*.md] [行106, critic-completeness.md行76, critic-effectiveness.md行75, critic-generality.md行81] [{task_id} プレースホルダが使用されているが、SKILL.md Phase 0 Step 4 でパス変数として定義されていない] → [SKILL.md 92-106行の各サブエージェントへのプロンプトにパス変数として {task_id} を追加するか、テンプレート側で TaskUpdate 呼び出しを削除する] [impact: medium] [effort: low]
- [参照整合性: phase1a-variant-generation.md のパス変数 {user_requirements} が条件付き定義]: [SKILL.md] [163-164行] [エージェント定義が新規作成の場合のみ {user_requirements} が定義されるが、テンプレート側は常に変数を参照する可能性がある] → [SKILL.md 163行を「常に定義（既存の場合は空文字列）」に変更するか、テンプレート phase1a-variant-generation.md でガード条件を追加する] [impact: medium] [effort: low]
- [出力フォーマット決定性: Phase 1A/1B の返答フォーマットが固定行数でない]: [templates/phase1a-variant-generation.md, templates/phase1b-variant-generation.md] [21-41行, 20-34行] [「以下のフォーマットで結果サマリのみ返答する」と指示しているが、構造分析結果の行数やバリアント数が可変のため、親が返答を解析する際にパーサーを必要とする] → [返答を1行サマリに変更（例: variants: {N}件生成完了、または単一行の確認メッセージ）し、詳細はファイルに保存させる] [impact: low] [effort: medium]
- [参照整合性: phase6b-proven-techniques-update.md のパス変数 {agent_name} が未定義]: [SKILL.md] [353行] [{agent_name} をパス変数として phase6b-proven-techniques-update.md に渡しているが、テンプレート内で {agent_name} プレースホルダは使用されていない] → [SKILL.md 353行から {agent_name} を削除する] [impact: low] [effort: low]

#### 改善提案
- [条件分岐の完全性: Phase 0 perspective 自動生成 Step 2 のフォールバック]: [SKILL.md] [78-80行] [「ファイルが見つからない場合は {reference_perspective_path} を空とする」とあるが、参照ファイルが空の場合にテンプレート generate-perspective.md がどう動作すべきかの指示がない] → [テンプレート generate-perspective.md に「reference_perspective_path が空の場合はスキーマのみ参照して生成」の明示的な分岐を追加する] [impact: low] [effort: low]
- [出力フォーマット決定性: Phase 0 のテキスト出力が完全固定でない]: [SKILL.md] [140-146行] [perspective の取得方法が「既存 / 自動生成」の2値だが、実際は「検索成功 / ファイル名パターン一致 / 自動生成」の3値である可能性がある] → [出力を「既存（perspective-source.md） / 既存（パターン一致） / 自動生成」の3値に明示化する] [impact: low] [effort: low]
- [条件分岐の完全性: Phase 3 の収束判定による実行回数分岐の前提条件]: [SKILL.md] [223-225行] [「収束判定が達成済みの場合（前回ラウンドの Phase 5 で判定）」とあるが、Phase 1A（初回ラウンド）の場合は前回ラウンドが存在しない] → [「収束判定が達成済みの場合（Phase 1B 時のみ適用、Phase 1A は常に2回実行）」に明示化する] [impact: low] [effort: low]
- [冪等性: Phase 3 開始前の既存結果削除が対象ディレクトリ限定]: [SKILL.md] [213行] [rm コマンドで results/v{NNN}-*.md を削除するが、NNN は現在のラウンド番号。過去ラウンドの結果は保持されるため冪等性の問題はないが、再実行時に失敗タスクの残骸が残る可能性がある] → [削除対象を明示的に「該当ラウンドの results/ ファイルのみ削除」と記述する] [impact: low] [effort: low]
- [条件分岐の完全性: Phase 4 の result_run2_path が存在しない場合]: [SKILL.md] [266-273行] [Phase 3 で収束時は1回のみ実行するが、Phase 4 のテンプレートは result_run1_path と result_run2_path の両方を要求している] → [テンプレート phase4-scoring.md に「result_run2_path が存在しない場合（収束時）は Run1 のみ採点し、SD = N/A とする」の条件分岐を追加する] [impact: medium] [effort: medium]
- [曖昧表現: SKILL.md 全般の「以下を実行する」]: [SKILL.md] [複数箇所（84, 131, 152, 174, 196, 228, 287, 323, 336, 346）] [「Task ツールで以下を実行する」の「以下」が、次の段落全体を指すのか、テンプレート指示の1行のみを指すのかが文脈に依存する] → [「Task ツールで以下のテンプレート指示を実行する:」に統一する] [impact: low] [effort: low]
- [出力フォーマット決定性: Phase 2 の返答フォーマットが固定行数でない]: [templates/phase2-test-document.md] [16-33行] [問題数とボーナス数が可変のため、返答行数が固定でない] → [「問題数: {N}、ボーナス: {M}」の1行サマリに変更し、詳細テーブルはファイルに保存させる] [impact: low] [effort: low]

#### 良い点
- [参照整合性: ファイルパスの一貫性]: 全てのテンプレート内プレースホルダ（{approach_catalog_path}, {knowledge_path}, {perspective_path}, 等）が SKILL.md のパス変数リストで定義されており、未定義変数がほぼない（{task_id}, {user_requirements} の条件付き定義を除く）
- [冪等性: Write 前の Read 確認が適切]: Phase 0 の knowledge.md 初期化（122-126行）と perspective 解決（54-66行）で、ファイル存在確認 → 不在時のみ初期化の分岐が明示されている
- [条件分岐の完全性: エラーハンドリングパスが明示的]: Phase 3（247-253行）と Phase 4（275-281行）で、成功数に応じた3分岐（全成功/一部成功/失敗）が明確に定義され、ユーザー選択による処理フロー（再試行/除外/中断）が記述されている
