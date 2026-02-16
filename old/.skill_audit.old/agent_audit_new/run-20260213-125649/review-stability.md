### 安定性レビュー結果

#### 重大な問題
- [参照整合性: 未定義パス変数]: [SKILL.md] [行88] [テンプレート `knowledge-init-template.md` に `{user_requirements}` 変数が渡されていないが、テンプレート側では `{perspective の概要から抽出した目的}` として使用を期待] → [Phase 0 の knowledge.md 初期化サブエージェント委譲で `{user_requirements}` を明示的に渡すか、テンプレート側の指示を「perspective_source_path の概要セクションから抽出」に修正する] [impact: high] [effort: low]
- [参照整合性: 未定義パス変数]: [templates/phase1a-variant-generation.md] [行9] [`{user_requirements}` 変数が Phase 0 で条件付き（新規作成時のみ）でしか定義されないが、テンプレート内で無条件に参照される可能性がある] → [SKILL.md 行172-173 で「エージェント定義が新規作成の場合: `{user_requirements}` を渡す」という条件付き変数定義を、常に空文字列または perspective から抽出した要件に置き換える] [impact: high] [effort: medium]
- [条件分岐の完全性: デフォルト処理未定義]: [SKILL.md] [行336] [プロンプト選択で「ベースライン以外を選択した場合」「ベースラインを選択した場合」の2分岐があるが、選択肢に「評価した全プロンプト名」が含まれるためベースライン・バリアント以外のプロンプトを選択した場合の処理が未定義] → [選択肢を「ベースライン」「バリアント1」「バリアント2」のように明示的に列挙するか、「ベースライン以外」分岐を「選択したプロンプトがベースラインと異なる場合」に変更する] [impact: medium] [effort: low]
- [参照整合性: ファイル実在確認]: [SKILL.md] [行84] [`.claude/skills/agent_bench_new/perspectives/design/security.md` を固定パスとして参照しているが、ファイルが見つからない場合のフォールバック処理が「`{reference_perspective_path}` を空とする」のみで、その後の Step 3 サブエージェント委譲で空パスを Read する指示が含まれている可能性がある] → [Step 2 で「ファイルが見つからない場合は `{reference_perspective_path}` を空文字列とし、Step 3 で Read をスキップする」旨を明記する] [impact: medium] [effort: low]
- [冪等性: 部分失敗時の状態破壊]: [SKILL.md] [行222] [Phase 3 開始前に既存 results/ ファイルを削除するが、Phase 3 が部分失敗した場合（一部プロンプトのみ成功）、再試行時に成功済みプロンプトの結果も削除されるため再実行が必要になる] → [削除コマンドを `rm -f .agent_bench/{agent_name}/results/v{NNN}-*.md` から個別プロンプトごとの削除（`rm -f .agent_bench/{agent_name}/results/v{NNN}-{name}-*.md` をサブエージェント起動直前に実行）に変更するか、削除処理自体を除去してサブエージェントに Write 前の既存ファイル削除を任せる] [impact: high] [effort: medium]

#### 改善提案
- [出力フォーマット決定性: サブエージェント返答行数の曖昧性]: [templates/phase1a-variant-generation.md] [行9-40] [「以下のフォーマットで結果サマリのみ返答する」とあるが、構造分析結果のテーブル行数が可変（「...」で省略可能）なため、親が受け取る返答長が不定] → [テーブル行数を明示（例: 「全6次元の分析結果を記載」）するか、サブエージェント返答を1行サマリに制限し詳細はファイルに保存させる] [impact: medium] [effort: medium]
- [出力フォーマット決定性: サブエージェント返答行数の曖昧性]: [templates/phase1b-variant-generation.md] [行20-34] [「結果サマリのみ返答する」とあるが、バリアント数が1個または2個で可変のため返答行数が不定] → [「常に2個のバリアントを生成」または「バリアント数: {N}」行を追加して行数を固定する] [impact: low] [effort: low]
- [条件分岐の完全性: エッジケース未定義]: [SKILL.md] [行193] [`.agent_audit/{agent_name}/run-*/audit-*.md` の Glob 検索で「最新ラウンドのファイルのみ抽出する」とあるが、複数ラウンドの audit 結果が存在する場合の最新判定ロジックが未定義] → [「run-* ディレクトリをタイムスタンプ降順でソートし、最新ディレクトリのファイルのみ使用」など具体的な抽出方法を明記する] [impact: medium] [effort: low]
- [参照整合性: テンプレート内プレースホルダ未使用]: [templates/perspective/critic-completeness.md, critic-clarity.md, critic-effectiveness.md, critic-generality.md] [行106] [SKILL.md Phase 0 Step 4 で `{agent_path}` 変数を各批評エージェントに渡しているが、いずれの critic テンプレートも `{agent_path}` を使用していない] → [SKILL.md 行105 から `{agent_path}` 変数の受け渡しを削除する] [impact: low] [effort: low]
- [冪等性: ファイル重複生成リスク]: [templates/phase6a-deploy.md] [行5] [デプロイ処理で Write による上書き保存のみが指示されているが、SKILL.md 側で事前の差分確認と AskUserQuestion 承認があるため冪等性は保たれている。ただし、テンプレート単体で見ると Read → Write の冪等性パターンが明示されていない] → [テンプレート冒頭に「注記: SKILL.md 側で差分プレビューと承認が行われている前提」をすでに記載済み。改善不要] [impact: low] [effort: low]
- [指示の具体性: 曖昧表現]: [SKILL.md] [行316] [「ラウンド別性能推移テーブル」の表示で「初期スコア: {初期値} → 現在ベスト: {現在値}」とあるが、「現在」がどのラウンドを指すか曖昧] → [「初期スコア (Round 1 Baseline) → 最新ラウンドベスト (Round {N})」のように明示する] [impact: low] [effort: low]
- [出力フォーマット決定性: 返答フォーマット不統一]: [templates/phase4-scoring.md] [行10-18] [Run2 の有無で返答フォーマットが分岐するが、親が受け取る返答の行数パターンが2通り存在する] → [常に3行固定（prompt_name, Mean/SD, Run1/Run2 詳細）とし、Run2 不在時は「Run2=N/A」とする] [impact: low] [effort: low]

#### 良い点
- [冪等性: 既存ファイル検証]: Phase 0 の knowledge.md 検証処理で、必須セクションの存在確認 → 検証失敗時の再初期化フローが明示されており、破損状態からの回復が可能
- [参照整合性: テンプレート変数の一貫性]: 全テンプレートで `{variable}` プレースホルダが SKILL.md のパス変数定義と一致しており、命名規則も統一されている（一部未定義変数を除く）
- [出力フォーマット決定性: Phase 5 返答フォーマット]: Phase 5 サブエージェントの返答が7行固定フォーマットで明示されており、親の後続処理（Phase 6 での推奨判定提示）が安定して実行可能
