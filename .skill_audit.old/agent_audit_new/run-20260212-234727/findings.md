## 重大な問題

### C-1: 外部参照パスが旧スキル名を使用 [efficiency, architecture, effectiveness, stability]
- 対象: SKILL.md:64, 221
- 内容: `.claude/skills/agent_audit/` のパス参照が残存している。現在のスキル名 `agent_audit_new` と不一致であり、実行時に参照失敗する。具体的には行64の `group-classification.md` と行221の `apply-improvements.md` が該当
- 推奨: `.claude/skills/agent_audit_new/` に修正する、またはグループ分類基準の詳細（約7-10行）を SKILL.md に直接インライン化することを検討する
- impact: high, effort: low

### C-2: Phase 2 Step 4 サブエージェント失敗時の処理が未定義 [ux, architecture, effectiveness, stability]
- 対象: SKILL.md Phase 2 Step 4
- 内容: apply-improvements サブエージェント失敗時の挙動が記載されていない。変更サマリが返らない場合、ユーザーへのエラー通知、バックアップからの復旧手順、または中止判定のロジックが欠落している。Phase 3 で「変更詳細」を出力する際に参照すべき情報が存在せず、Phase 3 の出力が不完全になる
- 推奨: 「サブエージェント失敗時: エラーメッセージを出力し、バックアップパスを提示して終了する」を追加する
- impact: high, effort: medium

### C-3: Phase 1 findings ファイルの上書き動作が不明確 [stability]
- 対象: SKILL.md Phase 1
- 内容: サブエージェントが `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` に Write する際、既存ファイルを上書きするのか追記するのか、再実行時の挙動が不明
- 推奨: Phase 1 の冒頭で「既存 findings ファイルが存在する場合は削除する」または「Write は既存ファイルを上書きする」と明示する
- impact: high, effort: low

### C-4: 外部参照の実在性検証が欠落 [effectiveness]
- 対象: SKILL.md Phase 0 Step 3, Phase 2 検証ステップ
- 内容: YAML frontmatter の存在確認のみを行っているが、スキル外のファイルへの参照（group-classification.md 等）の実在性検証が欠落している。使い方セクションでは「外部データへの依存なく、常に同じ分析を実行します」と宣言しているが、実際には外部ファイルへの参照が存在する
- 推奨: Phase 0 で外部参照パスの存在確認を追加する、または外部参照を完全に除去する
- impact: high, effort: medium

### C-5: SKILL.md が目標行数超過 [efficiency]
- 対象: SKILL.md
- 内容: 約29行超過（目標250行に対し279行）。主な要因: Phase 0のグループ分類基準が埋め込まれている（行62-70）、Phase 2 Step 2aのper-item承認フローが詳細記述（行168-185）
- 推奨: Phase 2 per-item承認フローを簡素化する（推定10行節約）。（グループ分類基準は CONF-1 解決により SKILL.md にインライン化を採用）
- impact: medium, effort: medium

### C-6: 成功基準が推定困難 [effectiveness]
- 対象: SKILL.md 冒頭
- 内容: ワークフローの完了後に「目的を達成した」と判定できる条件が不明確。「改善」が実際にエージェントファイルを Edit して完了したことなのか、findings を生成したことなのか、ユーザーが承認したことなのかが不明。期待される最終成果物が不明瞭（変更されたエージェント定義ファイル? findings レポート? 両方?）
- 推奨: 期待される成果物を「使い方」セクションまたは冒頭の説明文に追記する。例: 「## 期待される動作\n1. `.agent_audit/{agent_name}/audit-*.md` に各次元の分析結果を生成\n2. ユーザーが承認した findings を `.agent_audit/{agent_name}/audit-approved.md` に保存\n3. 承認された findings を元にエージェント定義ファイルを Edit\n4. バックアップファイルを `{agent_path}.backup-*` に保存」
- impact: high, effort: low

### C-7: Phase 2 検証失敗時の処理が不完全 [stability]
- 対象: SKILL.md:235
- 内容: 検証失敗時は警告を表示するが、Phase 3 で警告を再表示する処理が Phase 3 定義に存在しない
- 推奨: Phase 3 の冒頭に「検証フラグ {validation_failed} を確認し、失敗時は警告セクションを追加」する処理を明記する
- impact: medium, effort: medium

### C-8: Phase 1 全失敗時の判定基準が曖昧 [stability]
- 対象: SKILL.md:129
- 内容: 「全て失敗した場合」の判定が「findings ファイルが存在しない、または空」だが、「空」の定義が不明（0バイト？ヘッダのみ？Summary セクションなし？）
- 推奨: 「空」を「0バイトまたは `## Summary` セクションが存在しない」と定義する
- impact: medium, effort: low

## 改善提案

### I-1: Phase 1 サブエージェントへの返答指示にフィールド区切りが不明確 [stability]
- 対象: SKILL.md:118
- 内容: 返答フォーマット `dim: {次元名}, critical: {N}, improvement: {M}, info: {K}` が1行なのか複数行なのか、区切り文字が `, ` なのか改行なのか不明
- 推奨: 返答フォーマットを「4行形式（各行に1フィールド）: `dim: {次元名}\ncritical: {N}\nimprovement: {M}\ninfo: {K}`」と明示する
- impact: medium, effort: low

### I-2: Phase 0のファイル不在時メッセージが簡素 [ux]
- 対象: SKILL.md Phase 0
- 内容: agent_path の Read 失敗時に「エラー出力して終了」とあるが、メッセージの具体的内容（ファイルパス、原因、対処法）が記載されていない
- 推奨: エラーメッセージに「ファイルパス: {agent_path}、原因: ファイルが存在しません、対処法: ファイルパスを確認してください」等の詳細を追加する
- impact: medium, effort: low

### I-3: Phase 1全失敗時の原因要約がない [ux]
- 対象: SKILL.md Phase 1
- 内容: 全次元の分析失敗時に「Phase 1: 全次元の分析に失敗しました。」とあるが、失敗理由の集約（共通エラー、次元ごとの原因）が含まれていない
- 推奨: 失敗理由を集約して出力する。例: 「⚠ 全次元の分析に失敗しました。共通原因: {エラー概要}」
- impact: medium, effort: medium

### I-4: Phase 1 部分失敗時のユーザー通知の詳細不足 [effectiveness]
- 対象: SKILL.md Phase 1 エラーハンドリング
- 内容: Phase 1 で一部の次元が失敗した場合、「成功した次元の結果のみで Phase 2 に進む」とあるが、失敗した次元の情報欠落により分析の完全性が損なわれる点をユーザーに明示的に通知すべき
- 推奨: 失敗した次元を明示する。例: 「⚠ {失敗次元数}次元の分析に失敗しました。残りの次元で継続します。失敗した次元: {dim_list}」
- impact: medium, effort: low

### I-5: 「ファイル全体の書き換えが必要な場合」の基準が不明 [stability]
- 対象: templates/apply-improvements.md:23
- 内容: 「ファイル全体の書き換えが必要な場合のみ使用する」が曖昧（変更箇所数？変更行数の割合？セクション全削除？）
- 推奨: 「変更が10箇所を超える場合、またはファイル構造を大幅に変更する場合のみ Write を使用する。それ以外は Edit を優先する」と具体化する
- impact: medium, effort: low

### I-6: Fast mode未対応 [ux]
- 対象: SKILL.md Phase 0, Phase 2
- 内容: 全フェーズで AskUserQuestion を実行するが、Fast mode での中断スキップが記載されていない。MEMORY.md によれば「fastモードで中間確認をスキップ可能に」が推奨されている
- 推奨: Fast mode パラメータを追加し、有効時は Phase 2 の per-item 承認をスキップして自動承認する
- impact: medium, effort: medium

### I-7: サブエージェント返答行数の明示不足 [efficiency]
- 対象: templates/apply-improvements.md
- 内容: Phase 2 Step 4のapply-improvementsサブエージェントの返答行数が「可変」とされているが、SKILL.mdでは返答フォーマットの行数上限が明示されていない。サブエージェント失敗時の判定が不安定になる可能性
- 推奨: テンプレートに「返答は変更サマリのみ（推奨: 100行以内）」と明示する
- impact: medium, effort: low

### I-8: Phase 1 エラーハンドリングでの件数抽出ロジックが複雑 [stability]
- 対象: SKILL.md:126
- 内容: 「件数はファイル内の `## Summary` セクションから抽出する（抽出失敗時は findings ファイル内の `### {ID_PREFIX}-` ブロック数から推定する）」が2段階フォールバックだが、サブエージェント返答にも件数が含まれている（行118）。返答優先か、ファイル優先か不明
- 推奨: 「サブエージェント返答の件数を優先し、返答が不完全な場合のみファイルから抽出する」と優先順位を明示する
- impact: low, effort: low

### I-9: テンプレート変数の定義が不足 [stability]
- 対象: templates/apply-improvements.md:3-5
- 内容: `{approved_findings_path}` と `{agent_path}` は使用されているが、SKILL.md のパス変数リストに明示されていない（行223-224 で暗黙的に渡されている）
- 推奨: SKILL.md の Phase 0 または冒頭に「Phase 2 Step 4 で使用するパス変数」セクションを追加し、`{approved_findings_path}`, `{agent_path}` を定義する
- impact: low, effort: low

---
注: 改善提案を 5 件省略しました（合計 14 件中上位 9 件を表示）。省略された項目は次回実行で検出されます。
