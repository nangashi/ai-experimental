## 重大な問題

### C-1: Phase 0 perspective 検証失敗時のデータ損失 [stability]
- 対象: SKILL.md:127
- 内容: 必須セクション検証失敗時に「エラー出力してスキル終了」としているが、Step 5 で再生成した perspective が検証失敗した場合、Step 3 の初期生成版も失われる（上書き済み）。リカバリ不能
- 推奨: Step 5 の再生成時に一時ファイルに保存し、検証成功後に正式版を上書きする。または検証失敗時に Step 3 の初期生成版を復元する
- impact: medium, effort: medium

### C-2: Phase 1A/1B テンプレートへの未定義パス変数 [stability]
- 対象: SKILL.md:88, templates/phase1a-variant-generation.md:9
- 内容: テンプレート `knowledge-init-template.md` に `{user_requirements}` 変数が渡されていないが、テンプレート側では使用を期待。また、`{user_requirements}` 変数が Phase 0 で条件付き（新規作成時のみ）でしか定義されないが、テンプレート内で無条件に参照される可能性がある
- 推奨: Phase 0 の knowledge.md 初期化で `{user_requirements}` を明示的に渡すか、テンプレート側の指示を「perspective_source_path の概要セクションから抽出」に修正する。また、SKILL.md で `{user_requirements}` を常に空文字列または perspective から抽出した要件に置き換える
- impact: high, effort: medium

### C-3: Phase 1B の audit 結果検索ロジックの曖昧性 [stability, architecture]
- 対象: SKILL.md:193-197
- 内容: 「最新ラウンドのファイルのみ抽出」の判定基準が未定義。run-YYYYMMDD-HHMMSS パターンのソート方法（辞書順/時刻順）、複数ディレクトリ存在時の処理が不明。実行時エラーまたは誤ファイル参照のリスク
- 推奨: 「run-* ディレクトリをタイムスタンプ降順でソートし、最新ディレクトリのファイルのみ使用」など具体的な抽出方法を明記する
- impact: medium, effort: low

### C-4: Phase 3 削除処理の競合リスク [stability, architecture]
- 対象: SKILL.md:222
- 内容: Phase 3 開始前の `rm -f .agent_bench/{agent_name}/results/v{NNN}-*.md` が並列実行・再試行時に既存結果ファイルを削除する可能性がある。再試行分岐が複数ありうる処理で冪等性を担保できない。また、Phase 3 が部分失敗した場合（一部プロンプトのみ成功）、再試行時に成功済みプロンプトの結果も削除されるため再実行が必要になる
- 推奨: 削除コマンドを個別プロンプトごとの削除（`rm -f .agent_bench/{agent_name}/results/v{NNN}-{name}-*.md` をサブエージェント起動直前に実行）に変更するか、削除処理自体を除去してサブエージェントに Write 前の既存ファイル削除を任せる
- impact: high, effort: medium

### C-5: Phase 3/4 エラーハンドリングの未定義分岐 [architecture]
- 対象: SKILL.md:259-262, 287-290
- 内容: 再試行失敗時の処理が「再度確認を求める」と曖昧。無限ループまたは中断判定基準が不明確
- 推奨: 最大再試行回数（例: 2回）を設定し、超過時は自動中断またはユーザー選択肢を「中断/継続」に限定する
- impact: medium, effort: low

### C-6: Phase 6 プロンプト選択の条件分岐の不完全性 [stability]
- 対象: SKILL.md:336
- 内容: プロンプト選択で「ベースライン以外を選択した場合」「ベースラインを選択した場合」の2分岐があるが、選択肢に「評価した全プロンプト名」が含まれるためベースライン・バリアント以外のプロンプトを選択した場合の処理が未定義
- 推奨: 選択肢を「ベースライン」「バリアント1」「バリアント2」のように明示的に列挙するか、「ベースライン以外」分岐を「選択したプロンプトがベースラインと異なる場合」に変更する
- impact: medium, effort: low

### C-7: Phase 0 reference_perspective 読み込み失敗時のフォールバック不完全 [stability]
- 対象: SKILL.md:84
- 内容: `.claude/skills/agent_bench_new/perspectives/design/security.md` を固定パスとして参照しているが、ファイルが見つからない場合のフォールバック処理が「`{reference_perspective_path}` を空とする」のみで、その後の Step 3 サブエージェント委譲で空パスを Read する指示が含まれている可能性がある
- 推奨: Step 2 で「ファイルが見つからない場合は `{reference_perspective_path}` を空文字列とし、Step 3 で Read をスキップする」旨を明記する
- impact: medium, effort: low

## 改善提案

### I-1: Phase 3 の収束判定条件の参照先の不明確性 [effectiveness]
- 対象: Phase 3
- 内容: 「収束判定が達成済みの場合」の判定ロジックが「knowledge.md の最新ラウンドサマリの convergence フィールドを参照し、前回ラウンドの Phase 5 で判定」と記載されているが、knowledge.md の「最新ラウンドサマリ」セクションの構造定義が knowledge-init-template.md に記載されていない。Phase 5 で convergence フィールドを返答することは確認できるが、knowledge.md に convergence がどのように記録されているかの仕様が不明確
- 推奨: knowledge-init-template.md に「最新ラウンドサマリ」セクションの構造（フィールド名・形式）を明示する
- impact: medium, effort: medium

### I-2: Phase 0 perspective 自動生成のエラーハンドリング不足 [effectiveness]
- 対象: Phase 0 Step 3
- 内容: perspective 初期生成でサブエージェント自体が失敗した場合（ツールエラー・タイムアウト等）の処理記述がない。Step 6 の検証失敗は記述されているが、Step 3 の Task 起動失敗時の処理フローが不明確
- 推奨: Step 3 でサブエージェント失敗時の処理（リトライ/スキル終了/ユーザー確認）を明記する
- impact: medium, effort: low

### I-3: Phase 0 perspective 検証の Read 重複 [efficiency]
- 対象: SKILL.md:125
- 内容: Phase 0 Step 6 の検証で、perspective を Read で読み込むが、この perspective は直前の Step 5 line 70 で既に `.agent_bench/{agent_name}/perspective.md` として保存されており、親コンテキストに内容が残っている。再読み込みせずセクション検証のみ実行すべき
- 推奨: Step 6 で perspective の再読み込みを削除し、Step 5 保存時の内容を用いてセクション検証を実行する
- impact: medium, effort: low

### I-4: Phase 3 結果ファイル重複読み込み [efficiency]
- 対象: SKILL.md:248-250
- 内容: Phase 3 で `{prompt_path}`, `{test_doc_path}`, `{result_path}` のパス変数が2回記載されている（248-250行と251-253行が同一内容）。サブエージェントへの指示が重複し、親コンテキストを無駄に消費する
- 推奨: 重複行を削除し、パス変数定義を1回のみ記載する
- impact: medium, effort: low

### I-5: Phase 6A と 6B の並列実行記述の誤り [architecture]
- 対象: SKILL.md:371-381
- 内容: 「B) とC) の完了を待ってから」としているが、C) が AskUserQuestion であり並列実行不可。C) の結果が確定しないと次アクション分岐できない。記述が実装フローと矛盾
- 推奨: C) を直列実行に変更し、「B) の完了を待ち、C) を実行してから」に修正する
- impact: low, effort: low

### I-6: Phase 4 ベースライン失敗時の早期検出不足 [effectiveness]
- 対象: Phase 4
- 内容: 「ベースラインが失敗した場合は中断」と記載されているが、ベースライン採点失敗の検出方法（全サブエージェント完了後の成功数集計時に判定するのか、ベースラインのみ先に検証するのか）が不明確。ベースライン失敗を早期検出できる場合、他のプロンプトの採点を待たずに中断できるが、現在の記述では全タスク完了後の判定となり非効率の可能性がある
- 推奨: ベースラインのみ先に実行し、失敗時は即座に中断する処理フローを明示する
- impact: low, effort: low

### I-7: Phase 5 から Phase 6A への情報伝達の冗長性 [effectiveness]
- 対象: Phase 6A knowledge 更新
- 内容: Phase 5 のサブエージェント返答から recommended と reason をテキスト変数として Phase 6A に渡しているが、Phase 5 で生成されたレポートファイル (report_save_path) に同じ情報が含まれている。knowledge 更新テンプレート (phase6a-knowledge-update.md) はレポートファイルを既に読み込むため、recommended と reason をパス変数として追加で渡す必要性が不明確
- 推奨: レポートファイルから recommended と reason を抽出できる場合は、パス変数を削減してデータフローを簡素化する
- impact: low, effort: low

### I-8: サブエージェント返答フォーマットの可変性 [stability]
- 対象: templates/phase1a-variant-generation.md:9-40, phase1b-variant-generation.md:20-34
- 内容: Phase 1A で「以下のフォーマットで結果サマリのみ返答する」とあるが、構造分析結果のテーブル行数が可変（「...」で省略可能）なため、親が受け取る返答長が不定。Phase 1B でも「結果サマリのみ返答する」とあるが、バリアント数が1個または2個で可変のため返答行数が不定
- 推奨: Phase 1A でテーブル行数を明示（例: 「全6次元の分析結果を記載」）するか、サブエージェント返答を1行サマリに制限し詳細はファイルに保存させる。Phase 1B で「常に2個のバリアントを生成」または「バリアント数: {N}」行を追加して行数を固定する
- impact: medium, effort: medium

### I-9: 完了基準の曖昧性 [effectiveness]
- 対象: SKILL.md 冒頭
- 内容: 「構造最適化の完了基準」で「収束判定基準を満たす」と記載されているが、収束判定基準を満たした後のユーザーアクション（Phase 6 での「次ラウンド/終了」選択）が必須か任意かが不明確。収束後も継続可能なのか、自動終了なのか、ユーザー判断に委ねるのかの方針が明示されていない
- 推奨: 収束判定後のワークフロー（自動終了/ユーザー選択/次ラウンド継続可否）を明示する
- impact: low, effort: low
