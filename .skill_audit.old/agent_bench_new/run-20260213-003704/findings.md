## 重大な問題

### C-1: エラー通知: Phase 1A/1B 失敗時のメッセージが不足 [ux]
- 対象: SKILL.md:Phase 1A/1B
- 内容: サブエージェント失敗時に「エラー内容を出力してスキルを終了する」とあるが、原因の説明・対処法・復旧手順が含まれていない。他フェーズ（Phase 0 perspective自動生成、Phase 2、Phase 3）では詳細なエラーメッセージ構造が定義されている
- 推奨: Phase 0 perspective自動生成（77-84行）のエラーメッセージ構造に倣い、失敗原因・ユーザー対処法・ファイルパス例を含む構造化されたメッセージフォーマットを定義する
- impact: high, effort: low

### C-2: 目的の明確性: 成功基準の推定困難 [effectiveness]
- 対象: SKILL.md:冒頭
- 内容: ワークフロー完了後の「目的達成」判定条件が推定できない。「テストに対する性能を反復的に比較評価して最適化」とあるが、何回ラウンドを実行すれば最適化完了なのか、目標スコアの定義、収束判定後のアクション（強制終了 or ユーザー継続可能）が不明確。Phase 6 で「収束の可能性あり」を付記してユーザーに継続/終了を選択させるが、スキルとしての終了条件が定義されていない
- 推奨: SKILL.md に「成功基準」セクションを追加し、「収束判定が2回連続で該当した場合、またはユーザーが終了を選択した場合にスキル完了とする」等の終了条件を明記する
- impact: high, effort: low

### C-3: 参照整合性: 存在しないセクション参照 [stability]
- 対象: phase6-extract-top-techniques.md:line 6
- 内容: `## 効果テーブル` セクションを参照しているが、knowledge-init-template.md で初期化される knowledge.md には「## 効果が確認された構造変化」「## 効果が限定的/逆効果だった構造変化」セクションのみが存在し、`## 効果テーブル` セクションが存在しない。phase6a-knowledge-update.md で効果テーブルが生成されることが前提だが、テンプレートに明記されていない
- 推奨: knowledge-init-template.md に `## 効果テーブル` セクションのプレースホルダーを追加するか、phase6-extract-top-techniques.md の参照セクション名を既存セクション名に修正する
- impact: high, effort: medium

### C-4: 条件分岐の完全性: 存在確認なしの Read [stability]
- 対象: phase0-perspective-validation.md:line 8-9
- 内容: 必須セクション確認で "# パースペクティブ" または "# Perspective" および "## 評価観点" または "## Evaluation Criteria" を確認しているが、実際の perspective ファイルには "## 概要"、"## 評価スコープ"、"## スコープ外" が存在する（phase0-perspective-generation.md line 82参照）。セクション名の不一致により検証失敗の可能性
- 推奨: phase0-perspective-validation.md の必須セクション名を実際の perspective ファイルの構造に合わせて修正する
- impact: high, effort: low

### C-5: SKILL.md が目標の 250行を大幅超過（390行） [efficiency]
- 対象: SKILL.md
- 内容: 推定140行の浪費。主な原因は Phase 6 Step 2 の複雑な逐次・並列混在処理（L318-372, 54行）、Phase 0 の perspective 自動生成手順（L69-85, 17行）、Phase 1A/1B の audit 統合確認手順（L179-186, 8行）。親コンテキストに保持する必要のない詳細な分岐ロジックが多数記載されている
- 推奨: Phase 6 Step 2 の処理をテンプレートに外部化し、SKILL.md には「Read templates/phase6-step2.md and follow instructions」のみを記載。Phase 0 の perspective 自動生成手順も同様に外部化を検討
- impact: high, effort: medium

### C-6: ユーザー確認の欠落: Phase 6 Step 2A knowledge.md 更新の承認なし [ux]
- 対象: SKILL.md:Phase 6 Step 2A
- 内容: knowledge.md はスキルの累積データファイルであり、更新は反復的最適化の核心機能だが、AskUserQuestion による承認がない。Phase 0 perspective自動生成（モード選択）、Phase 1A/1B（上書き確認）、Phase 6 Step 2C（次アクション選択）には承認があるのに対し、この更新処理は自動実行される
- 推奨: knowledge.md 更新前に更新内容のサマリをユーザーに提示し、承認を求める AskUserQuestion を追加する
- impact: medium, effort: low

### C-7: 出力フォーマット決定性: 採点サブエージェント返答の曖昧性 [stability]
- 対象: phase4-scoring.md:line 11-12
- 内容: サマリ出力で "Mean={X.X}, SD={X.X}" の有効桁数が曖昧。一方で実際の例は小数第1位だが、他箇所では第2位が使われている。統一された桁数指定が必要
- 推奨: "Mean={X.XX}（小数第2位まで）" のように有効桁数を明示的に指定する
- impact: medium, effort: low

### C-8: 参照整合性: 未定義変数の使用 [stability]
- 対象: SKILL.md:line 62
- 内容: `{existing_perspectives_summary}` → サブエージェントに渡されるが、phase0-perspective-resolution.md テンプレート内で使用されていない
- 推奨: 使用されない変数は削除するか、使用予定の場合はテンプレート内での使用箇所を明記する
- impact: medium, effort: low

### C-9: perspective 自動生成の4並列批評が過剰 [efficiency]
- 対象: templates/phase0-perspective-generation.md
- 内容: 推定4サブエージェント×平均80行の入力 = 320行。Step 4 で4つのサブエージェント（clarity, generality, effectiveness, completeness）を並列起動し、Step 5 で統合・再生成を行う設計。初回実行時のみの処理だが、4つの批評の差分が小さく、統合効率が低い。簡略版（phase0-perspective-generation-simple.md）が存在するが選択は手動
- 推奨: 初回実行時はデフォルトで簡略版を使用し、エラー発生時のみ標準モード（4並列批評）に自動フォールバックする設計に変更する
- impact: medium, effort: low

## 改善提案

### I-1: Phase 0 の perspective 検証をインライン化 [efficiency]
- 対象: templates/phase0-perspective-validation.md
- 内容: perspective 検証サブエージェント（phase0-perspective-validation.md）は必須セクションの存在確認のみを行う（21行の単純処理）。親が直接 Read + Grep で実施すれば、サブエージェント起動コストを削減できる
- 推奨: SKILL.md の Phase 0 で直接 Read + Grep による検証を実行し、テンプレートファイルを削除する
- impact: high, effort: low

### I-2: Phase 6 の top-techniques 抽出が非効率 [efficiency]
- 対象: SKILL.md:Phase 6, templates/phase6-extract-top-techniques.md
- 内容: 推定1サブエージェント×knowledge.md全体読み込み（ラウンド数に応じて数百行）。Phase 6A（knowledge更新）の直後に、knowledge.md を再度全文 Read して上位3件を抽出するサブエージェント（L336-344）を起動。knowledge 更新サブエージェントの返答に上位3件を含めれば、サブエージェント1回分を削減可能
- 推奨: phase6a-knowledge-update.md の返答フォーマットに「top_techniques: {上位3件のカンマ区切りリスト}」フィールドを追加し、phase6-extract-top-techniques.md を削除する
- impact: high, effort: low

### I-3: Phase 6 Step 2 の逐次・並列混在を簡略化 [efficiency]
- 対象: SKILL.md:Phase 6 Step 2
- 内容: 推定20-30行の削減。現在の設計は A（knowledge更新）完了 → A.2（top-techniques抽出）完了 → B（proven-techniques更新）とC（次アクション選択）を並列実行。A.2 を A の一部に統合し、B と C を待つだけの設計にすれば手順が簡潔化する
- 推奨: I-2 の推奨に従い、A.2 を A に統合した後、SKILL.md の Phase 6 Step 2 の記述を「A完了 → B, C 並列実行 → 完了待機」の3ステップに簡略化する
- impact: high, effort: low

### I-4: 外部ディレクトリへの参照 [architecture]
- 対象: SKILL.md:line 171-174
- 内容: `.agent_audit/{agent_name}/audit-*.md` へのハードコードされた直接参照がある。Phase 1B で agent_audit の出力ディレクトリを直接検索している。agent_audit の内部構造変更（ディレクトリ名変更等）に脆弱
- 推奨: agent_audit スキルが出力パスを明示的に返す設計に変更するか、パラメータ化して skill 内に audit 結果をコピーする仕組みを導入する
- impact: medium, effort: medium

### I-5: 成果物の構造検証: knowledge.md 更新後の検証欠如 [architecture]
- 対象: SKILL.md:Phase 6
- 内容: knowledge.md の更新処理に対して、必須セクション（バリエーションステータステーブル、効果テーブル、改善のための考慮事項等）の存在を確認する構造検証の記述がない。更新処理が失敗した場合、不完全な knowledge.md が次ラウンドで参照される可能性がある
- 推奨: phase6a-knowledge-update.md にセクション検証ステップを追加し、失敗時に警告を出力する
- impact: medium, effort: low

### I-6: エラー耐性: Phase 1A/1B スキップ時のファイル不在ケース [architecture]
- 対象: SKILL.md:Phase 1A/1B
- 内容: 既存プロンプトファイルの上書き確認で「スキップして Phase 2 へ」を選択した場合、Phase 2 で必要なベースラインファイル（v{NNN}-baseline.md）が存在しない可能性がある。Phase 2 以降でファイル不在時の処理フローが定義されていない
- 推奨: スキップ選択時にベースラインファイルの存在を確認し、不在時はエラーメッセージを出力して終了する
- impact: medium, effort: low

### I-7: データフロー妥当性: 暗黙的依存 — Phase 1B の audit パス変数参照 [effectiveness]
- 対象: SKILL.md:line 171-174
- 内容: agent_audit スキルの出力ディレクトリを直接参照している。「将来的には agent_audit が明示的な出力パスを返す設計に変更すべき」とコメントされているが、現状は暗黙的依存が残存。agent_audit 実行の成否確認・存在確認が Phase 0 で行われていない
- 推奨: Phase 0 で agent_audit の実行有無を確認し、未実行の場合は Phase 1B で audit 統合をスキップする旨をユーザーに説明する
- impact: medium, effort: medium

### I-8: 進捗可視性: Phase 4 開始メッセージ欠落 [ux]
- 対象: SKILL.md:Phase 4
- 内容: Phase 3 と Phase 5 では「## Phase N」形式の出力が明示されているが、Phase 4 には開始時の進捗メッセージがない。並列サブエージェント実行前にフェーズ名・目的・タスク数が出力されない
- 推奨: Phase 4 開始時に「## Phase 4: 採点\n評価タスク数: {N}」を出力する指示を追加する
- impact: medium, effort: low

### I-9: 進捗可視性: Phase 6 Step 1 の進捗メッセージ不足 [ux]
- 対象: SKILL.md:Phase 6 Step 1
- 内容: プロンプト選択・デプロイステップの開始時に「## Phase 6: プロンプト選択・デプロイ・次アクション」のような出力がない。Phase 0-5 では各フェーズ開始時に進捗情報が出力されているが、Phase 6 は Step 2A の knowledge.md 更新完了メッセージから始まる
- 推奨: Phase 6 Step 1 開始時に「## Phase 6: プロンプト選択・デプロイ・次アクション」を出力する指示を追加する
- impact: medium, effort: low
