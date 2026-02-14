## 重大な問題

### C-1: Phase 6 Step 2 の並列実行順序が不明確 [effectiveness]
- 対象: SKILL.md:281-323
- 内容: 「まず」ナレッジ更新を実行し完了を待つと記載されているが、直後に「次に以下の2つを同時に実行する」として B) スキル知見フィードバック と C) 次アクション選択 を並列実行すると記述されている。しかし line 321 で「B) スキル知見フィードバックサブエージェントの完了を待ってから」と記載され、C) の完了を待つ必要があるかが不明。C) は AskUserQuestion を含むため完了を待つ必要があるはずだが、明示されていない
- 推奨: 「B) と C) を並列実行 → B) の完了を待つ → 選択結果に応じて分岐」と実行順序を明示する
- impact: high, effort: low

### C-2: 参照整合性: 未定義変数の使用 [stability]
- 対象: templates/perspective/critic-effectiveness.md:22
- 内容: {existing_perspectives_summary} がパス変数リストで定義されていない
- 推奨: SKILL.md Phase 0 の perspective/critic-* サブエージェント起動箇所（L38-48）にパス変数として追加、または当該変数参照を削除
- impact: high, effort: medium

### C-3: 冪等性: ファイル上書き前の存在確認なし [stability]
- 対象: SKILL.md:111, 133 (Phase 1A, Phase 1B)
- 内容: prompts_dir に Write でバリアント保存時、既存ファイルの存在確認がなく再実行時に重複生成される可能性
- 推奨: 各 Phase で「Glob で {prompts_dir}/v{NNN}-*.md を検索し、既存ファイルがある場合は AskUserQuestion で上書き/スキップを選択する」処理を追加
- impact: high, effort: medium

### C-4: SKILL.md 行数超過 [efficiency]
- 対象: SKILL.md
- 内容: 340行で目標250行に対して36%超過。親コンテキストに大量のワークフロー詳細が保持される（推定90行超過コンテキスト）
- 推奨: ワークフロー詳細をテンプレートに外部化し、SKILL.md は各フェーズの呼び出しとパス変数のみに簡素化
- impact: high, effort: medium

### C-5: ユーザー確認欠落: Phase 0のエージェント目的ヒアリング条件が曖昧 [ux]
- 対象: Phase 0
- 内容: 「AskUserQuestion」でエージェント目的のヒアリングを行うと記載されているが、どの条件下で実行されるか不明確（新規作成時のみか、既存ファイル読み込み時も含むか）。analysis.md の E セクションでも「不明」と記録されている
- 推奨: 新規/既存の判定タイミングとヒアリング実行タイミングの整合性を明示
- impact: high, effort: low

## 改善提案

### I-1: Phase 3 指示の埋め込み [architecture, ux, efficiency]
- 対象: SKILL.md:192-199
- 内容: Phase 3 で各サブエージェントに渡す指示が8行のインラインブロックとして記述されている。テンプレートファイルに外部化すべき。進捗メッセージもない
- 推奨: テンプレートファイルに外部化し、SKILL.md の行数を削減。並列評価開始時に「Phase 3: 評価を開始します（{N}タスク）」等の宣言を追加
- impact: medium, effort: low

### I-2: Phase 6 Step 2 の並列実行記述の曖昧さ [architecture]
- 対象: SKILL.md:297-321
- 内容: ナレッジ更新（A）完了後に、スキル知見フィードバック（B）と次アクション選択（C）を「同時に実行」と記述されているが、C は B の完了を待つ必要がある
- 推奨: 「B と C を同時起動し、C は B の完了を待つ」等の明確な実行順序が必要
- impact: medium, effort: low

### I-3: エラー通知: Phase 2失敗時の再試行回数制限が未通知 [ux]
- 対象: Phase 2
- 内容: 「再試行 / 中断」選択肢を提示するが、再試行が1回のみに制限されていることがユーザーに伝わらない。再試行失敗後の選択肢も不明確（中断のみか、別オプションも選択できるか記載なし）
- 推奨: エラーメッセージに「再試行は1回のみ可能です」と明記し、再試行失敗後の選択肢を列挙
- impact: medium, effort: low

### I-4: エラー通知: Phase 4失敗時の「ベースライン失敗時の中断」条件が不明確 [ux]
- 対象: Phase 4
- 内容: 「失敗プロンプトを除外して続行」の選択肢があるが、「ベースラインが失敗した場合は中断」という条件がテキストのみで記述されており、エラーメッセージで明示されていない
- 推奨: エラーメッセージに「ベースラインが失敗した場合は中断されます」と明記し、選択不可能な選択肢を提示しないようにする
- impact: medium, effort: low

### I-5: 出力フォーマット決定性: サブエージェント返答行数が未定義 [stability]
- 対象: templates/phase0-perspective-generation.md:62
- 内容: 「perspective 自動生成完了: {perspective_save_path}」とだけ返答すると記述されているが、改行を含まないことが明示されていない
- 推奨: 「以下の1行を返答する:\n```\nperspective 自動生成完了: {perspective_save_path}\n```」に修正し、改行を含まないことを明示
- impact: medium, effort: low

### I-6: 出力フォーマット決定性: テンプレート内の返答フォーマットが曖昧 [stability]
- 対象: templates/perspective/critic-completeness.md:90-102
- 内容: Missing Element Detection Evaluation テーブルの行数が未定義
- 推奨: 「Table with 5+ rows:」を「Table with exactly 5-8 rows (one per essential design element):」に修正
- impact: medium, effort: low

### I-7: 条件分岐の完全性: 暗黙的条件の存在 [stability]
- 対象: templates/phase1b-variant-generation.md:8-10
- 内容: 「audit_dim1_path が指定されている場合: Read で読み込む」の else 節（指定されていない場合の処理）が不明確
- 推奨: 「指定されている場合」の後に「指定されていない場合: audit 統合候補セクションは省略し、次の手順へ進む」を追加
- impact: medium, effort: low

### I-8: エラー通知: Phase 0 perspective自動生成失敗時のメッセージに対処法がない [ux]
- 対象: Phase 0
- 内容: 「エラー内容を出力してスキルを終了する」とあるが、エラーメッセージの内容（原因説明、対処法）が具体的に記述されていない。4並列批評レビュー失敗の場合、どの批評が失敗したか、再試行可能かが不明
- 推奨: エラーメッセージに失敗した批評の特定情報と対処法（手動でperspective.mdを作成する、等）を含める
- impact: medium, effort: medium

### I-9: phase0-perspective-generation における4並列批評の複雑性 [efficiency]
- 対象: templates/phase0-perspective-generation.md, templates/perspective/critic-*.md × 4
- 内容: perspective自動生成時に4並列批評 + 統合 + 再生成の複雑なフローを持つ。失敗率が高く、コンテキスト浪費のリスクが大きい（推定4000トークン/実行）
- 推奨: 批評の数を削減、またはフォールバック時に簡略版の自動生成パスを提供
- impact: medium, effort: high

---
注: 改善提案を 11 件省略しました（合計 20 件中上位 9 件を表示）。省略された項目は次回実行で検出されます。
