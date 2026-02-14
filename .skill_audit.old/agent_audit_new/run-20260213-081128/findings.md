## 重大な問題

### C-1: 外部参照のパス不整合 [stability, architecture, effectiveness, efficiency]
- 対象: SKILL.md:64, SKILL.md:116, SKILL.md:221
- 内容: スキル名は `agent_audit_new` だが、全エージェント参照パスが `.claude/skills/agent_audit/` を指している。正しくは `.claude/skills/agent_audit_new/` であるべき。Phase 0 のグループ分類基準読み込み、Phase 1 の分析エージェント起動、Phase 2 Step 4 の改善適用テンプレート読み込みが全て失敗する
- 推奨: SKILL.md 内の全ての `.claude/skills/agent_audit/` を `.claude/skills/agent_audit_new/` に置換する。または、スキル内の相対パスとして `group-classification.md`, `agents/{dim_path}.md`, `templates/apply-improvements.md` と記載する
- impact: high, effort: low

### C-2: Phase 2 Step 4 改善適用失敗時のフォールバック未定義 [stability, architecture, effectiveness]
- 対象: SKILL.md:Phase 2 Step 4 (行219-226)
- 内容: apply-improvements サブエージェントが失敗した場合の処理フローが定義されていない。バックアップは作成されるが、サブエージェント実行成否や変更適用の成否検証がない。返答が得られない場合、または返答が不正なフォーマットの場合の処理が未定義
- 推奨: apply-improvements サブエージェント失敗時のフォールバック処理を追加する:「サブエージェント完了確認: 返答内容に `modified:` または `skipped:` が含まれるか検証。検証失敗時は「改善適用に失敗しました。詳細: {サブエージェント返答}」とテキスト出力し、バックアップからのロールバック手順を提示してPhase 3へ進む」
- impact: high, effort: medium

### C-3: 不可逆操作のガード欠落: ファイル上書き前の確認なし [ux]
- 対象: SKILL.md:Phase 2 Step 4
- 内容: エージェント定義ファイル `{agent_path}` への改善適用（Edit/Write）を実行する前に AskUserQuestion が配置されていない。バックアップは作成されるが、ユーザーが改善内容を確認する機会なく即座に上書きされる。改善適用後にロールバックが必要な場合、元の作業コンテキストが失われる
- 推奨: Phase 2 Step 4 の apply-improvements サブエージェント起動前に AskUserQuestion を追加し、承認済み findings の適用内容を確認させる
- impact: high, effort: low

## 改善提案

### I-1: Phase 1 エラーハンドリングの情報欠落 [effectiveness]
- 対象: SKILL.md:Phase 1 (行126-128)
- 内容: findings ファイルが存在しない、または空の場合に「Task ツールの返答から例外情報（エラーメッセージの要約）を抽出」と記載されているが、Task ツールがどのフォーマットで例外情報を返すかが未定義。実際にサブエージェント実行でエラーが発生した際に「分析失敗（{エラー概要}）」のエラー概要が空文字列または不明瞭なメッセージになる可能性がある
- 推奨: 「Task ツールの返答テキスト全体を `{error_text}` として保持し、`{error_text}` の先頭100文字を `{エラー概要}` として表示する」のように抽出方法を明示する
- impact: medium, effort: low

### I-2: サブエージェント返答のバリデーション欠落 [architecture]
- 対象: SKILL.md:Phase 1
- 内容: サブエージェントの返答フォーマットが `dim: {次元名}, critical: {N}, improvement: {M}, info: {K}` と定義されているが、返答内容がこのフォーマットに準拠しているかの検証ロジックが存在しない。返答がフォーマット不正の場合、件数抽出が失敗するリスクがある。findings ファイルからのフォールバック抽出はあるが、返答パース失敗時の明示的な処理フローがない
- 推奨: 返答フォーマット不正時に件数を「?」として表示し、findings ファイルから件数を推定する処理を追加する
- impact: medium, effort: low

### I-3: 参照整合性: プレースホルダ不一致 [stability]
- 対象: templates/apply-improvements.md:4-5
- 内容: プレースホルダ `{approved_findings_path}` と `{agent_path}` が使用されているが、SKILL.md のパス変数リストには記載がない
- 推奨: SKILL.md Phase 2 Step 4 (行219-224) のパス変数リストを「## パス変数」として独立セクション化し、`{agent_path}`, `{approved_findings_path}` を明示的に定義する
- impact: medium, effort: low

### I-4: 承認粒度の問題: 一括承認パターン [ux]
- 対象: SKILL.md:Phase 2 Step 2
- 内容: 「全て承認」オプションは {total} 件の findings を一括で承認する。critical/improvement が混在する場合でも個別内容を確認せずに全承認できてしまう。Step 2a の per-item 承認フローが用意されているため重大度は medium。ただし「全て承認」のデフォルト性によってユーザーが安易に選択するリスクがある
- 推奨: 「全て承認」選択前に AskUserQuestion で再確認を追加するか、critical と improvement の件数内訳を表示して注意を促す
- impact: medium, effort: low

### I-5: グループ分類基準の参照指示の曖昧性 [efficiency]
- 対象: SKILL.md:64
- 内容: 「詳細は `.claude/skills/agent_audit/group-classification.md` を参照」とあるが、実際には同一スキル内の `group-classification.md` を参照すべき。相対パスまたはスキル内パスに統一すべき
- 推奨: スキル内の相対パス表記に統一する（「詳細は `group-classification.md` を参照」）
- impact: medium, effort: low

### I-6: 並列分析時の部分成功の判定基準の曖昧さ [architecture]
- 対象: SKILL.md:Phase 1
- 内容: 「全て失敗した場合」のみエラー終了と定義されているが、「一部成功」の基準（最低必要成功数、critical次元の必須性等）が未定義。例えば IC 次元（全グループ共通）が失敗した場合でも継続するのか、グループ固有次元が全滅した場合はどうするのか等のポリシーが存在しない
- 推奨: 「IC 次元（instruction-clarity）が失敗した場合は警告表示して継続」「グループ固有次元が全滅した場合はエラー終了」等の最低成功基準を明示する
- impact: medium, effort: medium

### I-7: 条件分岐の完全性: per-item 承認の "Other" 分岐処理が曖昧 [stability]
- 対象: SKILL.md:Phase 2 Step 2a (行181)
- 内容: 「"Other" で修正内容をテキスト入力した場合は「修正して承認」として扱い、改善計画に含める」とあるが、その後の Step 3 保存フォーマットでは「修正内容」の記録方法が説明されているが、入力の検証・解析方法が未定義
- 推奨: Step 2a の "Other" 処理を明確化:「ユーザーが "Other" を選択した場合、入力されたテキストを `{user_modification}` として記録し、finding の `recommendation` を `{user_modification}` で置き換える。入力が空または "skip" 等の明示的な拒否を示す場合は「スキップ」として扱う」
- impact: medium, effort: low

### I-8: 冪等性: バックアップファイルの重複生成 [stability]
- 対象: SKILL.md:Phase 2 Step 4 (行217)
- 内容: バックアップコマンド `cp {agent_path} {agent_path}.backup-$(date +%Y%m%d-%H%M%S)` が再実行時に毎回新規ファイルを作成する
- 推奨: バックアップ作成前に既存バックアップの存在確認を追加する:「Bash で `ls {agent_path}.backup-* 2>/dev/null | tail -n 1` を実行し、最新バックアップが存在する場合はその時刻を表示して `AskUserQuestion` で新規バックアップ作成の要否を確認する。存在しない、またはユーザーが承認した場合のみ新規バックアップを作成する」
- impact: medium, effort: medium

### I-9: 成果物の構造検証の欠落 [architecture]
- 対象: SKILL.md:Phase 2 Step 4
- 内容: apply-improvements サブエージェントが生成する変更後のエージェント定義に対する構造検証は、Phase 2 検証ステップで YAML frontmatter のみチェックしている（L232-235）。しかし、findings の「推奨」に従った変更が実際に適用されたかの検証（変更内容のdiff確認、セクション存在確認等）は実施されていない。サブエージェントの返答（modified/skipped サマリ）を信頼するのみで、実際のファイル内容との一致を確認していない
- 推奨: Phase 2 検証ステップで、変更前後のdiffを確認するか、承認済み findings で指定されたセクション/行が実際に変更されたかを検証する処理を追加する
- impact: medium, effort: medium
