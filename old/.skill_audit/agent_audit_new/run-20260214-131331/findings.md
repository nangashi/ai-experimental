## 重大な問題

なし

## 改善提案

### I-1: frontmatter チェックの冪等性不明瞭 [stability]
- 対象: SKILL.md:Phase 0
- 内容: Phase 0 Step 6 で「Phase 1 の各サブエージェントは既存の findings ファイルを Write で上書きする（再実行時は前回の findings は削除される）」と記述されているが、この動作はサブエージェント側の実装依存。SKILL.md には「既存ファイルを Write で上書き」という指示が Phase 1 のサブエージェントプロンプトに含まれていない。findings ファイルの冪等性がサブエージェントの暗黙的な動作に依存している
- 推奨: Phase 1 のサブエージェントプロンプトに「既存の findings ファイルが存在する場合は Write で上書きする」旨を明示する、または Phase 0 Step 6 で既存の findings ファイルを削除する処理を追加する
- impact: medium, effort: low

### I-2: common-rules.md の埋め込み削減 [efficiency]
- 対象: SKILL.md:Phase 1
- 内容: SKILL.md 148-194行で common-rules.md（44行）を全サブエージェントプロンプトに直接埋め込んでいる。Phase 1 で3-5次元の並列サブエージェントを起動するため、同じ44行が複数回コンテキストに展開される。推定節約量: 220-440行（5サブエージェント × 44行）
- 推奨: サブエージェントプロンプトを「{skill_path}/agents/shared/common-rules.md を Read し、そこに定義された共通ルールを参照してください」のパス変数渡しに変更し、各次元エージェント定義ファイルの冒頭で common-rules.md を Read させることで、親のプロンプト構築コストを削減できる
- impact: medium, effort: low

### I-3: agent_content 変数の未使用 [efficiency]
- 対象: SKILL.md:Phase 0
- 内容: Phase 0 Step 2/4 で `{agent_path}` を Read する処理が記述されているが、読み込んだ内容を `{agent_content}` 変数に保持しながらも、Phase 1 以降でこの変数が参照されていない。親がエージェント定義の全文を保持する必要はなく、サブエージェントが `{agent_path}` を直接 Read するべき。推定節約量: エージェント定義ファイルの行数分（通常150-300行）
- 推奨: Phase 0 Step 2/4 はファイル存在確認と frontmatter チェック+グループ分類に専念し、全文保持は不要と明記すべき
- impact: medium, effort: low

### I-4: 欠落ステップ: findings-summary.md の未読取り [effectiveness]
- 対象: SKILL.md:Phase 2 Step 2
- 内容: SKILL.md Line 236 で「findings の詳細は `.agent_audit/{agent_name}/findings-summary.md` を Read で読み込み、テキスト出力として表示する」と記述されているが、Step 2（Line 240-254）では AskUserQuestion の直前にテキスト出力として一覧表示はあるものの、findings-summary.md の Read 処理が明示されていない。collect-findings.md テンプレートが生成した findings-summary.md を親が読み込む処理が欠落している
- 推奨: Phase 2 Step 2 の冒頭に findings-summary.md の Read 処理を明示的に記述する
- impact: medium, effort: low
