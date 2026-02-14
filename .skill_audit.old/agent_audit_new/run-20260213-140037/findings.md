## 重大な問題

### C-1: 外部参照の残存 [architecture, efficiency, stability, effectiveness]
- 対象: SKILL.md:64
- 内容: `.claude/skills/agent_audit/group-classification.md` への参照が記載されているが、実際には同一スキル内の `group-classification.md` を参照すべき。外部スキルへの誤参照として修正が必要
- 推奨: 参照パスを削除し、「詳細は同一スキル内の `group-classification.md` を参照」のように修正する
- impact: medium, effort: low

### C-2: 目的の明確性: スキル目的の境界が不明確 [effectiveness]
- 対象: SKILL.md 冒頭
- 内容: スキル目的が「構造最適化（agent_bench）では解決できない内容レベルの問題を特定・改善」と agent_bench との対比で定義されているが、「内容レベルの問題」の具体的定義・範囲が不明確。成功基準（どのような状態になれば目的達成か）が推定不可
- 推奨: 目的を「エージェント定義の評価基準・スコープ定義・指示記述を5次元（IC/CE/SA/DC/WC/OF）で分析し、曖昧性・実行不可能性・矛盾を検出して修正候補を提示する」のように具体的成果物と入出力で定義すべき
- impact: high, effort: low

### C-3: 不可逆操作のガード欠落: バックアップ作成失敗時の処理 [ux]
- 対象: SKILL.md:217
- 内容: Phase 2 Step 4 で `cp {agent_path} {agent_path}.backup-$(date +%Y%m%d-%H%M%S)` を実行しているが、バックアップ作成失敗時（ディスク容量不足、書き込み権限なし等）の検証・エラーハンドリングが記述されていない。バックアップなしで改善適用が続行されると、検証失敗時（234行）にロールバック手段が存在しない。ユーザーはデータ損失のリスクにさらされる
- 推奨: バックアップ作成後に `test -f {backup_path}` で存在確認を行い、失敗時は改善適用を中止してエラー報告する
- impact: high, effort: low

### C-4: 不可逆操作のガード欠落: agent_path上書き前の最終確認 [ux]
- 対象: SKILL.md:217-226
- 内容: Phase 2 Step 4 の改善適用サブエージェント（217-226行）が Edit/Write で {agent_path} を直接上書きするが、サブエージェント起動直前に最終確認の AskUserQuestion が配置されていない。バックアップは存在するが、意図しない自動適用を防ぐ最後のガードポイントが欠落している。ユーザーは承認した指摘内容と異なる変更が適用されるリスクがある
- 推奨: Step 4 の Task 起動前に「承認した {approved_count} 件の指摘を {agent_path} に適用します。よろしいですか？」のような最終確認を追加する
- impact: high, effort: low

## 改善提案

### I-1: B. 出力フォーマット決定性: Phase 1 エラーハンドリングの findings ファイル内容抽出方法が曖昧 [stability]
- 対象: SKILL.md:126-127
- 内容: 「Summary セクションから抽出する（抽出失敗時はfindings ファイル内の `### {ID_PREFIX}-` ブロック数から推定する）」という指示だが、Summary セクションのフォーマットが明示されていない
- 推奨: 「Summary セクション内の `critical: N`, `improvement: M`, `info: K` の行から抽出する。この行が存在しない場合は…」のように具体化する
- impact: medium, effort: low

### I-2: C. 条件分岐の完全性: Phase 2 Step 2a の AskUserQuestion 選択肢 "Other" の処理が不明確 [stability]
- 対象: SKILL.md:181
- 内容: 「ユーザーが "Other" で修正内容をテキスト入力した場合は「修正して承認」として扱い」と記載されているが、AskUserQuestion の選択肢に "Other" が含まれていない
- 推奨: 選択肢を「承認」「スキップ」「修正して承認（テキスト入力）」「残りすべて承認」「キャンセル」のように明示する
- impact: medium, effort: low

### I-3: D. 冪等性: Phase 0 Step 6 でディレクトリ作成時の既存確認なし [stability]
- 対象: SKILL.md:81
- 内容: `mkdir -p` により既存ディレクトリがあっても成功するが、再実行時に既存 findings ファイルが Phase 1 で上書きされる可能性について言及がない
- 推奨: 「既存の `.agent_audit/{agent_name}/` ディレクトリがある場合、Phase 1 の各次元は findings ファイルを上書きする。過去の分析結果を保持したい場合は事前にディレクトリをリネームまたはバックアップすること」のように注意喚起を追加する
- impact: medium, effort: low

### I-4: 欠落ステップ: Phase 2 Step 4 の検証ステップが適用失敗を検出できない [effectiveness]
- 対象: Phase 2 検証ステップ
- 内容: 検証が YAML frontmatter の存在確認のみで、サブエージェントが実際に findings を適用したか、または適用中にエラーが発生したかを確認する処理が欠落している。サブエージェント返答の構造検証（`modified: N件` 形式の確認）が必要
- 推奨: 検証ステップでサブエージェント返答の `modified:` 行を確認し、0件の場合は警告を表示する
- impact: medium, effort: low

### I-5: エッジケース処理記述: Phase 2 Step 4 の部分失敗ハンドリングが不明確 [effectiveness]
- 対象: Phase 2 Step 4
- 内容: テンプレート apply-improvements.md は `modified: N件, skipped: K件` 形式を返すが、skipped が全件だった場合（modified: 0件）の処理が SKILL.md に記述されていない。この場合もバックアップ削除や検証スキップ等の判断が必要
- 推奨: 「modified: 0件の場合は警告を表示し、バックアップを保持したまま Phase 3 へ進む」のように明示する
- impact: medium, effort: low

### I-6: dimension agent ファイルの行数が過大 [efficiency]
- 対象: agents/
- 内容: 平均185行（最大206行）のテンプレートをサブエージェントが読み込む。Phase 1で3-5個の並列実行があるため、合計555-925行を消費。検出戦略の冗長性・例示の重複が原因。評価テーブルの削減や検出戦略の統合で平均120-130行に削減可能（約30%節約）
- 推奨: 次元テンプレートの検出戦略セクションを統合し、評価テーブルの冗長な例示を削除する
- impact: medium, effort: medium

### I-7: テンプレート apply-improvements.md の返答行数制約未定義 [efficiency]
- 対象: Phase 2 Step 4
- 内容: サブエージェント返答が「可変（`modified: N件, skipped: K件`形式）」と記載されているが、modified/skipped リストが多数の場合に親コンテキストを圧迫する。最大行数制約（例: modified/skipped各5件まで、超過時は件数のみ表示）を定義すべき
- 推奨: 「modified/skipped リストは各5件まで、超過時は『… (他N件)』形式で省略」のように制約を定義する
- impact: medium, effort: low

### I-8: ワークフロー明確性: Phase 2 Step 2a での「残りすべて承認」の挙動 [ux]
- 対象: SKILL.md:184
- 内容: 「残りすべて承認」は「この指摘を含め、未確認の全指摘を承認としてループを終了する」と記載されているが、critical と improvement が混在する場合、critical のみを全承認するのか、severity 関係なく全承認するのかが不明確。ユーザーは意図しない severity の指摘を承認するリスクがある
- 推奨: 「残りすべて承認」を「現在の severity（critical/improvement）内の残り全指摘を承認」のように明確化する
- impact: medium, effort: low

### I-9: ワークフロー明確性: 検証失敗時の次アクション未定義 [ux]
- 対象: Phase 2 検証ステップ
- 内容: 235行で検証失敗時にロールバックコマンドを提示するが、その後の処理フローが不明確（Phase 3 へ進むのか、スキル終了か）。Phase 3 で警告表示（236行）は記載されているが、検証失敗時に Phase 3 をスキップするべきか否かの判断基準がない。ユーザーは検証失敗後の操作に迷う
- 推奨: 「検証失敗時はロールバックコマンドを提示してスキルを終了する。ロールバック後は再度 /agent_audit で分析を実行すること」のように明示する
- impact: medium, effort: medium
