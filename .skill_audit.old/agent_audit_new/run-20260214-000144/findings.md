## 重大な問題

### C-1: 外部スキルパスへの参照 [architecture, stability]
- 対象: SKILL.md:64, 115, 221
- 内容: スキル名が `agent_audit_new` であるにも関わらず、SKILL.md内で古いスキルパス `.claude/skills/agent_audit/` を参照している。これは実行時に Read 失敗を引き起こし、Phase 0のグループ分類（line 64）、Phase 1のサブエージェント起動（line 115）、Phase 2の改善適用（line 221）が全て失敗する。3箇所全てがクリティカルパスで、全てのフェーズでRead失敗となり、スキルが完全に動作不能となる
- 推奨: 全ての参照を `.claude/skills/agent_audit_new/` に修正する
- impact: high, effort: low

### C-2: データフロー妥当性: Phase 3で参照する変更詳細が収集されていない [effectiveness]
- 対象: Phase 2 Step 4, Phase 3
- 内容: Phase 3のサマリ出力(lines 264-265)で `{finding ID リスト}` と `{finding ID: スキップ理由}` を表示する記述があるが、Phase 2 Step 4のサブエージェント(apply-improvements.md)は個別finding IDごとの適用状態を返答していない。集計値(`modified: {N}件`, `skipped: {K}件`)のみ返答する仕様であり、Phase 3で個別IDを参照できない
- 推奨: apply-improvements.mdの返答フォーマットを拡張し、各finding IDと適用状態のマッピング(`{finding ID} → modified/skipped: {理由}`)を返答させ、Phase 2 Step 4でこの情報を保持する。または、apply-improvements.mdが変更詳細を別ファイル(`.agent_audit/{agent_name}/changes-summary.md`)に保存し、Phase 3がそのファイルをReadする
- impact: high, effort: medium

### C-3: 条件分岐の欠落: Phase 2 改善適用失敗時のelse節 [stability]
- 対象: SKILL.md:213-227
- 内容: Phase 2 Step 4 でサブエージェントに改善適用を委譲するが、サブエージェント実行失敗時の処理が定義されていない。検証ステップ（line 228-236）は改善適用が完了した前提で構造検証を行うが、サブエージェント自体の失敗（Task ツールのエラー、サブエージェントのクラッシュ等）への対応が欠落している
- 推奨: サブエージェント失敗時の動作（エラー出力 + Phase 3 へスキップ、またはユーザー確認）を明示する
- impact: high, effort: medium

### C-4: 冪等性: Phase 1再実行時のfindingsファイル重複 [stability]
- 対象: SKILL.md:111-122
- 内容: Phase 1でサブエージェントが `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` にfindingsを Write で保存するが、再実行時に既存ファイルが存在する場合の処理が定義されていない。サブエージェントがファイル上書き（Write）を使用する場合、再実行は冪等だが、Edit や追記を使用する場合は重複する。テンプレート（agents/*/md）で Write を使用することが保証されていない
- 推奨: Phase 1開始時に既存の audit-*.md ファイルを削除するステップを追加するか、サブエージェントテンプレートで Write 使用を明示する
- impact: medium, effort: low

### C-5: 参照整合性: agent_bench配下ファイルのスコープ外参照 [stability]
- 対象: SKILL.md 全体構造
- 内容: スキルディレクトリ内に `agent_bench/` サブディレクトリが存在し、別スキル（agent_benchスキル）の全ファイルが含まれている。analysis.md (line 72) の注記によれば「agent_bench配下のファイルは外部スキルとして独立しているため、本スキルの外部参照には含めない」とあるが、実際にはスキルディレクトリ内に配置されている。これはスキル境界が曖昧であり、参照整合性の判定基準が不明確
- 推奨: agent_bench ファイルをスキルディレクトリ外に移動するか、スキル構造を明確に分離する
- impact: medium, effort: high

### C-6: 参照整合性: Phase 1サブエージェント返答フォーマットの不一致 [stability]
- 対象: SKILL.md:118-123, 126
- 内容: Phase 1のサブエージェント返答は「`dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`」と定義されているが、line 126 で「findings ファイル内の `## Summary` セクションから抽出する（抽出失敗時は findings ファイル内の `### {ID_PREFIX}-` ブロック数から推定する）」とある。これは返答フォーマットとfindings ファイルフォーマットの2つの情報源が存在し、一貫性が保証されていない。サブエージェントが返答を誤った場合、親がfindings ファイルから再抽出するフォールバック機構だが、この動作は曖昧
- 推奨: 件数取得はfindings ファイルの Summary セクションのみに一本化し、サブエージェント返答からの抽出を削除する
- impact: medium, effort: low

## 改善提案

### I-1: エッジケース処理適正化: AskUserQuestionフォールバック不足 [effectiveness]
- 対象: Phase 2 Step 4 検証ステップ
- 内容: 検証失敗時(line 235)はロールバックコマンドを提示するが、ユーザーに実行可否を確認するAskUserQuestionがない。自動ロールバックすべきか、ユーザー判断に委ねるべきか設計意図が不明
- 推奨: 検証失敗時にAskUserQuestionで対応方針を確認する記述を追加する。選択肢: 「自動ロールバック」「手動で修正」「Phase 3へ進む(警告付き)」
- impact: medium, effort: low

### I-2: データフロー妥当性: Phase 2 Step 4返答の親コンテキスト保持 [effectiveness]
- 対象: Phase 2 Step 4 → Phase 3
- 内容: apply-improvementsサブエージェントの返答を「テキスト出力する」(line 226)と記述されているが、Phase 3で参照する変更詳細として保持する指示がない。Phase 3のサマリで変更詳細を表示する場合、親コンテキストまたはファイルからの取得が必要
- 推奨: apply-improvementsの返答を変数(`{change_summary}`)として保持する指示を追加するか、変更詳細をファイル保存させてPhase 3でReadする手順を明示する
- impact: medium, effort: low

### I-3: Phase 2 Step 1の冗長Read [efficiency]
- 対象: SKILL.md:148
- 内容: findings ファイルを収集するため「Phase 1 で成功した全次元の findings ファイルを Read する」が、その直後に「各ファイルから severity が critical または improvement の finding を抽出」するため全ファイル内容を親コンテキストにロードしている。apply-improvements サブエージェントも approved_findings_path を直接 Read するため、親が全 findings を保持する必要はない。approved.md 生成時に必要な情報（ID/title/description/evidence/recommendation）のみ抽出し、詳細は findings ファイルに委譲すべき
- 推奨: approved.md 生成時に必要な情報（ID/title/description/evidence/recommendation）のみ抽出し、詳細は findings ファイルに委譲する
- impact: medium, effort: medium

### I-4: 出力フォーマット決定性: Phase 2 Step 4サブエージェント返答フォーマットの曖昧性 [stability]
- 対象: SKILL.md:226
- 内容: 「返答内容（変更サマリ）をテキスト出力する」とあるが、サブエージェントが返すべき具体的なフォーマットが定義されていない。テンプレート（apply-improvements.md）には返答フォーマット定義があるが、SKILL.md 側には「複数行（`modified: {N}件 ... skipped: {K}件 ...`）」という曖昧な記述のみ（line 123）。親がどのように返答を処理するか不明確
- 推奨: テンプレート側の返答フォーマットとSKILL.md の期待フォーマットを一致させる
- impact: medium, effort: low

### I-5: 条件分岐の適正化: Phase 1サブエージェント失敗判定の過剰分岐 [stability]
- 対象: SKILL.md:125-129
- 内容: Phase 1の成否判定で「findings ファイルが存在し、空でない → 成功」「存在しない、または空 → 失敗。Task ツールの返答から例外情報を抽出」とあるが、Task ツールのエラー処理は LLM が自然に実行できる。また、findings ファイル内の Summary セクション抽出失敗時の段階的リカバリ（ブロック数から推定）は階層2の過剰処理に該当する
- 推奨: 成否判定をシンプルに「findings ファイルが存在し、Summary セクションが含まれる → 成功」のみに簡素化し、抽出失敗時のフォールバックを削除する
- impact: low, effort: medium

### I-6: Phase 1エラーハンドリングの二重Read [efficiency]
- 対象: SKILL.md:126-127
- 内容: 各サブエージェントの成否判定で findings ファイルの存在確認とサマリ抽出を行い、抽出失敗時に findings ファイル内のブロック数をカウントする処理が記述されている。これは階層2（LLM委任）の範囲内であり、明示的な処理定義は不要。findings ファイルが存在すれば成功、存在しなければ失敗として扱い、件数はサブエージェント返答から取得する設計に簡素化できる
- 推奨: findings ファイルが存在すれば成功、存在しなければ失敗として扱い、件数はサブエージェント返答から取得する設計に簡素化する
- impact: low, effort: low

### I-7: 目的の明確性: 成功基準の明確化 [effectiveness]
- 対象: SKILL.md 冒頭の説明文
- 内容: 「使い方」セクションで期待される成果物(audit findings, approved findings, completion summary)は記載されているが、スキル完了後の状態(「目的を達成した」と判定する基準)が明示されていない。例: 「全ての指摘を確認し、ユーザーが選択した改善を適用完了した状態」「エージェント定義の構造検証が成功した状態」など
- 推奨: SKILL.md 6-10行目の目的記述に成功基準を追加する。例: 「...内容レベルの問題を特定・改善し、承認された変更を適用してエージェント定義を更新します。完了時にはバックアップ・変更詳細・検証結果が提供されます」
- impact: low, effort: low

### I-8: 指示の具体性: Phase 0 グループ分類の判定基準参照の曖昧性 [stability]
- 対象: SKILL.md:62-72
- 内容: グループ分類の判定ルール（概要）が記載されているが、「分類基準の詳細は `.claude/skills/agent_audit/group-classification.md` を参照」とある。親エージェントがこの判定を直接行う（サブエージェント不要、line 72）ため、判定に必要な全情報をSKILL.md に記載すべき。外部ファイル参照は親のコンテキストを増加させる
- 推奨: group-classification.md の全内容をSKILL.md の Phase 0 に埋め込むか、判定ルールを完全に記述する
- impact: low, effort: medium

### I-9: 条件分岐の欠落: Phase 0 frontmatter不在時の動作方針 [stability]
- 対象: SKILL.md:58
- 内容: frontmatter 不在時に「警告を出力するが処理は継続する」とあるが、エージェント定義でないファイル（README、ドキュメント等）を誤って指定された場合、Phase 1 以降の処理が無意味な分析を実行する。ユーザーに確認するか中止するかのフォールバックがない
- 推奨: AskUserQuestion で「エージェント定義ではない可能性があります。続行しますか？」の確認を追加する
- impact: low, effort: low
