## 重大な問題

### C-1: スキル外ファイル参照 [architecture]
- 対象: SKILL.md:174行
- 内容: agent_bench スキルへの外部参照 `.agent_audit/{agent_name}/audit-*.md` がスキルディレクトリ外のパスを参照している。Phase 1Bバリアント生成時にagent_benchとの連携を前提としているが、スキル内に該当データが存在しない
- 推奨: スキルディレクトリ外のファイルへの参照を削除し、スキル内にコピーするか、パラメータ化する
- impact: medium, effort: low

### C-2: 次元エージェントの過剰なコンテキスト消費 [efficiency]
- 対象: agents/*.md
- 内容: 次元エージェントファイルが平均180行と非常に大きく、サブエージェントに不要なPhase 2解説やAntipattern Catalogの詳細な記述が含まれている。実行に必要な情報はDetection Strategy部分のみであり、残りの約40%は冗長。推定コンテキスト浪費量: 1200-1600行/次元
- 推奨: 次元エージェント定義からPhase 2セクションとAntipattern Catalogを分離・外部化し、必要な情報のみを残す
- impact: high, effort: medium


## 改善提案

### I-1: 次元エージェント定義の Phase 2 セクション統合 [efficiency]
- 対象: agents/*.md
- 内容: Phase 1とPhase 2を別セクションとして記述しているが、Phase 2は単に「Phase 1で検出した問題をseverityでソートし、出力テンプレートに従って保存する」という定型処理。各次元エージェントで繰り返し記述するのではなく、SKILL.mdで一度定義し、次元エージェントには「Phase 1で検出した問題リストをSKILL.mdの標準フォーマットで保存する」旨のみ記述すれば十分。推定節約量: 250-350行×7ファイル = 1750-2450行
- 推奨: Phase 2の処理をSKILL.mdに一元化し、次元エージェントファイルから削除する
- impact: high, effort: high

### I-2: 次元エージェント定義の Antipattern Catalog 統合 [efficiency]
- 対象: agents/*.md
- 内容: 各次元エージェントがAntipattern Catalogを個別に記述しているが、これはDetection Strategy 5として「カタログ参照」に統合可能。外部ファイル（例: `.claude/skills/agent_audit_new/antipatterns/{dim}.md`）にカタログを抽出し、次元エージェントは「Read {antipattern_catalog_path}してチェックする」のみ記述すれば冗長性を削減できる。推定節約量: 200-300行×7ファイル = 1400-2100行
- 推奨: Antipattern Catalogを外部ファイルに抽出し、次元エージェントから削除する
- impact: high, effort: high

### I-3: 出力フォーマット決定性: Phase 1 サブエージェント起動時の返答フォーマット指示が曖昧 [stability]
- 対象: SKILL.md:134-139行
- 内容: 「以下のフォーマットで返答してください」のみで、行数・フィールド順序が明示されていない
- 推奨: サブエージェント起動プロンプトの返答指示を以下に置換: 「分析完了後、以下の1行フォーマットで返答してください（他の出力は含めない）: `dim: {次元名}, critical: {N}, improvement: {M}, info: {K}` 例: `dim: IC, critical: 2, improvement: 5, info: 1`」
- impact: medium, effort: low

### I-4: 出力フォーマット決定性: Phase 2 Step 2 の findings 一覧テーブルフォーマットが曖昧 [stability]
- 対象: SKILL.md:174-180行
- 内容: 表ヘッダーと列の内容は指定されているが、ID・severity・title の取得元が明示されていない
- 推奨: 「各 finding ファイルから finding ID（例: IC-01）、severity（critical/improvement）、title（finding の最初の見出し）を抽出してテーブルを作成する」と明記
- impact: medium, effort: low

### I-5: 成果物の構造検証欠如 [architecture]
- 対象: Phase 2 検証ステップ:249-256行
- 内容: 最終成果物（audit-approved.md）に対する構造検証がない。検証は agent_path の frontmatter のみをチェックしている
- 推奨: 成果物の必須セクション（「重大な問題」「改善提案」セクションの存在、finding ID形式の妥当性等）を検証する処理を追加
- impact: medium, effort: medium

### I-6: 指示の具体性: Phase 2 Step 2a の「ユーザーが "Other" でテキスト入力した場合」処理が曖昧 [stability]
- 対象: SKILL.md:200行
- 内容: AskUserQuestion の選択肢に "Other" がないにもかかわらず、Other 入力時の処理が定義されている
- 推奨: この記述を削除するか、AskUserQuestion の選択肢に「その他（修正内容を入力）」を明示的に追加する
- impact: medium, effort: low

### I-7: Phase 2 Step 2 テキスト出力の統合 [efficiency]
- 対象: SKILL.md:173-180
- 内容: 承認対象findingsの一覧をテキスト出力しているが、Step 2aのPer-item承認ループ内で個別に内容を表示している（189-198行）。一覧表示は不要。推定節約量: 20-30行
- 推奨: Step 2aで直接個別提示すれば十分。一覧表示のステップを削除する
- impact: low, effort: low

### I-8: 条件分岐の適正化: Phase 0 Step 7a の既存 findings 削除が条件分岐なし [stability]
- 対象: SKILL.md:102行
- 内容: `rm -f` は常に実行される指示になっているが、初回実行時と再実行時で動作が異なる意図が不明確
- 推奨: 「再実行時の findings 重複を防ぐため、Phase 1 の前に既存 audit-*.md を削除する（`rm -f .agent_audit/{agent_name}/audit-*.md`）」と記述を変更し、冪等性の意図を明示
- impact: low, effort: low

### I-9: 参照整合性: SKILL.md で言及された次元エージェントパスの定義が不完全 [stability]
- 対象: SKILL.md:108-113行
- 内容: dimensions テーブルに dim_path を列挙しているが、それらが `.claude/skills/agent_audit_new/agents/` 配下にあることが明示されていない
- 推奨: Step 8 の直後に「各 dim_path は `.claude/skills/agent_audit_new/agents/{dim_path}.md` の絶対パスに解決される」と追記
- impact: low, effort: low
