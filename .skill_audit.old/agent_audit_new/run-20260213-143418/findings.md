## 重大な問題

なし

## 改善提案

### I-1: Phase 2 Step 4 で 29 行のインライン指示をテンプレート参照パターンに統一すべき [architecture]
- 対象: SKILL.md Phase 2 Step 4 (行 231-261)
- 内容: 改善適用サブエージェント用の指示が SKILL.md 内に 29 行のインラインブロックとして記述されている。apply-improvements.md が既に存在し、29 行の指示の大部分と重複している。現在の SKILL.md の指示はテンプレートファイルのコピーになっており、2 箇所でメンテナンスが必要
- 推奨: 「`.claude/skills/agent_audit_new/templates/apply-improvements.md` を Read し、その指示に従って改善を適用してください。パス変数: `{agent_path}`: {絶対パス}, `{approved_findings_path}`: {絶対パス}` 完了後、以下のフォーマットで返答してください: modified: {N}件 ... skipped: {K}件 ...」形式に変更する
- impact: high, effort: low

### I-2: テンプレート内の未定義プレースホルダ [stability]
- 対象: templates/apply-improvements.md (行4, 5)
- 内容: `{approved_findings_path}` と `{agent_path}` プレースホルダが使用されているが、SKILL.md の「パス変数リスト」セクションで定義されていない（Phase 2 Step 4 のインライン Task prompt 内で定義されている）
- 推奨: SKILL.md に「## パス変数」セクションを追加し、全プレースホルダを一覧で定義する。テンプレートファイルと SKILL.md で使用される全変数を統一的に管理する
- impact: medium, effort: medium

### I-3: Phase 0 Step 6 既存 findings ファイルの上書き警告が不十分 [stability]
- 対象: SKILL.md Phase 0 Step 6 (行84)
- 内容: 「既存の findings ファイルが上書きされる可能性があることに注意」とあるが、注意喚起のみで具体的な回避方法（タイムスタンプ付きサブディレクトリの使用、既存ファイルの確認とバックアップ等）の提示がない
- 推奨: 冪等性確保の手順を追加する: 「既に `.agent_audit/{agent_name}/` が存在する場合、Bash で `ls .agent_audit/{agent_name}/audit-*.md 2>/dev/null` を実行し、既存 findings ファイルを列挙する。ファイルが存在する場合、`mkdir -p .agent_audit/{agent_name}/run-$(date +%Y%m%d-%H%M%S)/` のようにタイムスタンプ付きサブディレクトリを作成し、findings の保存先を `{run_dir}/audit-{ID_PREFIX}.md` に変更する」
- impact: medium, effort: high

### I-4: Phase 0 グループ抽出フォーマット未指定 [stability]
- 対象: SKILL.md Phase 0 Step 4 (行69-75)
- 内容: サブエージェント返答から `{agent_group}` を「抽出する」が、抽出失敗時の処理が未定義。形式不正時の動作が不明確
- 推奨: 抽出方法を明示する: 「返答から `group: {agent_group}` の形式で {agent_group} を抽出する。抽出失敗時（返答が形式に従わない場合）は `unclassified` をデフォルト値として使用する」
- impact: medium, effort: low

### I-5: Phase 2 Step 1 findings 抽出方法が未定義 [stability, effectiveness]
- 対象: SKILL.md Phase 2 Step 1 (行155-158)
- 内容: 「`###` ブロック単位」で finding を抽出するとあるが、ブロックの境界判定や必須フィールド（ID, severity, title, description 等）の有無による抽出成否判定が未定義。形式不正時の処理が不明確。findings ファイルの具体的な構造（セクション階層、フィールド名）が SKILL.md 内で定義されていない
- 推奨: 抽出ロジックを明示する: 「各 `###` で始まるブロックを finding として抽出。ブロック内に `[severity: critical]` または `[severity: improvement]` を含むもののみ対象。ID は `###` 直後のトークン（例: `CE-01`）、title は ID の後のテキスト、description/evidence/recommendation は各見出し（`- 内容:`, `- 根拠:`, `- 推奨:`）の後のテキストから取得。必須フィールドが欠落している場合は警告を表示し、そのブロックをスキップする」
- impact: medium, effort: medium

### I-6: Phase 1 で 8 行のインライン指示を完全にテンプレート化すべき [architecture]
- 対象: SKILL.md Phase 1 (行 123-127)
- 内容: 各次元エージェント用の Task prompt が SKILL.md 内に 8 行のインライン指示として埋め込まれている。8 行は 7 行の閾値を超えており、パス変数の説明が既に各次元エージェント内に存在する（"### Input Variables" セクション）ため、指示の重複を避けるべき
- 推奨: 各次元エージェントファイル（例: agents/evaluator/criteria-effectiveness.md）の末尾に「## 呼び出し方法」または「## 返答フォーマット」セクションを追加し、パス変数の受け渡しと返答形式をテンプレート内で定義する
- impact: medium, effort: low

### I-7: Phase 1 並列実行数の変動 [efficiency]
- 対象: Phase 1 並列実行
- 内容: グループ別次元数が3-5個に変動するため、最も多いhybrid(5次元)を基準にすると、次元エージェントの並列実行数が実行ごとに変わる。全次元エージェントが共通フレームワーク(54行)を読み込むため、5次元並列実行時は270行の重複読み込みが発生する。analysis-framework.md は全次元で同一の参照を行うため、親が1回読み込んで要約をサブエージェントに渡す方式に変更可能
- 推奨: 推定節約量: 10-20K tokens/実行
- impact: medium, effort: medium

### I-8: Phase 2 Step 1 findings 抽出の冗長性 [efficiency]
- 対象: Phase 2 Step 1
- 内容: Phase 1 で dim_summaries に件数を保存しているにもかかわらず、Phase 2 Step 1 で全 findings ファイルを再度 Read して件数を集計している。dim_summaries から直接件数を取得することで Read 操作を削減可能。一覧表示時のみ findings ファイルを読み込めばよい
- 推奨: 推定節約量: 5-10K tokens/実行
- impact: medium, effort: low

### I-9: 前回履歴との比較が未実装 [effectiveness]
- 対象: Phase 1-2
- 内容: SKILL.md 行87-89 で前回承認済み指摘を次元エージェントに渡しているが、その情報を Phase 2 で活用していない。前回と今回の findings を比較し、「前回承認済みの問題が再検出された」または「前回の問題が解決された」といった変化の報告ステップが欠落している
- 推奨: Phase 3 サマリに比較結果を含めることで、改善適用の効果を可視化できる
- impact: medium, effort: medium
