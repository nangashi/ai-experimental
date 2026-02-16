## 重大な問題

### C-1: スキルディレクトリパス誤記 [stability, efficiency, architecture]
- 対象: SKILL.md:行83,94,126,129,148,152-154,168,176-178,190,192-193,255,257,278,280,330,341,344
- 内容: 全テンプレート参照パスが `.claude/skills/agent_bench/` になっているが、正しくは `.claude/skills/agent_bench_new/` であるべき。Read 失敗によりスキル実行が全フェーズで中断する
- 推奨: `.claude/skills/agent_bench_new/templates/...` に全パスを修正する
- impact: high, effort: low

### C-2: 目的の明確性 - 成果物の宣言が不明確 [effectiveness]
- 対象: SKILL.md:冒頭・使い方セクション
- 内容: スキルの説明文に「各ラウンドで得られた知見を `knowledge.md` に蓄積し、反復的に改善します」とあるが、最終成果物が「最適化されたエージェント定義ファイル」なのか「knowledge.md の知見集」なのかが明示されていない。「使い方」セクションでは引数のみを記載し、期待される出力が記載されていない
- 推奨: SKILL.md 行6の後に「## 期待される成果物」セクションを追加し、「最適化されたエージェント定義ファイル（`agent_path` に上書き）、累計ラウンド数分の比較レポート（`.agent_bench/{agent_name}/reports/round-*.md`）、最適化の知見（`.agent_bench/{agent_name}/knowledge.md`）」と明記する
- impact: high, effort: low

### C-3: データフロー妥当性 - Phase 0 の user_requirements が Phase 1A に渡されない [effectiveness]
- 対象: SKILL.md:Phase 0, Phase 1A
- 内容: Phase 0 Step 1 で「エージェント定義が実質空または不足がある場合: AskUserQuestion でヒアリング」（行70-73）とあるが、Phase 1A のパス変数（行157-159）では「エージェント定義が新規作成の場合」のみ `{user_requirements}` を渡すと記載されている。エージェント定義ファイルが存在するが不足している場合、user_requirements が Phase 1A に渡されない
- 推奨: Phase 1A のパス変数リストに「エージェント定義が既存だが不足している場合: `{user_requirements}`: Phase 0 で収集した補足要件テキスト（存在する場合）」を追加する
- impact: high, effort: low

## 改善提案

### I-1: 冪等性 - knowledge.md の累計ラウンド数と効果テーブルの更新で再実行時の競合リスク [stability]
- 対象: templates/phase6a-knowledge-update.md:行8-14
- 内容: 再実行時に同一ラウンドのデータが重複追記される可能性
- 推奨: knowledge.md を Read して該当ラウンドのエントリが既に存在するか確認し、存在する場合は上書き、存在しない場合のみ追記する条件分岐を追加する
- impact: medium, effort: medium

### I-2: 冪等性 - proven-techniques.md の更新で再実行時のエントリ重複リスク [stability]
- 対象: templates/phase6b-proven-techniques-update.md:行28-44
- 内容: 同一知見の昇格処理を複数回実行するとエントリが重複する可能性
- 推奨: proven-techniques.md を Read して該当テクニックのエントリが既に存在するか確認し、存在する場合は統合/更新、存在しない場合のみ追加する条件分岐を明示する
- impact: medium, effort: medium

### I-3: エッジケース処理記述 - perspective-source.md 既存時の自動生成スキップ条件が曖昧 [effectiveness]
- 対象: SKILL.md:Phase 0:行64
- 内容: 「既に `.agent_bench/{agent_name}/perspective-source.md` が存在する場合は自動生成をスキップし、既存ファイルを使用する」とあるが、検証（Step 6）が実行されないため、既存ファイルが破損している場合やセクション欠落の場合にエラー検出が遅延する
- 推奨: 既存 perspective-source.md の検証ステップを追加し、検証失敗時は自動生成にフォールバックする処理を記述する
- impact: medium, effort: medium

### I-4: Phase 2 の knowledge.md 参照が Phase 1A のみで実行される場合に機能しない [effectiveness]
- 対象: templates/phase2-test-document.md
- 内容: Phase 2 テンプレート（phase2-test-document.md）では knowledge_path を参照して「過去と異なるドメインを選択する」（行6）と記載されているが、Phase 1A 後に Phase 2 が実行される場合は knowledge.md が初期状態（テストセット履歴が空）のため、ドメイン多様性の判定が機能しない
- 推奨: Phase 2 テンプレート内で「knowledge.md にテストセット履歴が存在しない場合は、初回として任意のドメインを選択する」と明記する
- impact: medium, effort: low

### I-5: Phase 3 失敗時の SD = N/A 処理が Phase 4/5 で参照されていない [effectiveness]
- 対象: SKILL.md:Phase 3:行238
- 内容: Phase 3 で「Run が1回のみのプロンプトは SD = N/A とする」と記載されているが、Phase 4 テンプレートには SD = N/A の場合の処理が記載されていない。Phase 5 の推奨判定で SD を参照する可能性があるが、N/A 時の扱いが不明
- 推奨: Phase 4 テンプレートに「Run が1つのみの場合は SD = N/A と記載する」と明記し、Phase 5 テンプレートに「SD = N/A の場合は推奨判定から除外する」と追記する
- impact: medium, effort: low

### I-6: Phase 6 Step 2B/2C の並列実行可能性 [efficiency]
- 対象: SKILL.md:行325-349
- 内容: Step 2A（knowledge 更新）完了後、Step 2B（proven-techniques 更新）と Step 2C（次アクション選択）は並列実行可能。2B は proven-techniques.md を読み書きし、2C は AskUserQuestion で確認のみ。データ依存なし
- 推奨: Phase 6 Step 2B と Step 2C を並列実行するように変更する
- impact: medium, effort: low

### I-7: 出力フォーマット決定性 - Phase 0 Step 4 の批評エージェントからの返答フォーマットが未定義 [stability]
- 対象: SKILL.md:行92-104
- 内容: 「SendMessage で報告」のみで、具体的な返答フォーマット（行数、セクション）が未定義
- 推奨: SendMessage の内容フォーマットを明示する。templates/perspective/critic-*.md では出力セクション構造が定義されているため、SKILL.md 側でも「重大な問題/改善提案セクションを含む形式で報告」と明記すべき
- impact: medium, effort: low

### I-8: Phase 1B の audit パス変数が空文字列の場合の処理が未定義 [effectiveness]
- 対象: SKILL.md:Phase 1B:行176-178, templates/phase1b-variant-generation.md:行18-19
- 内容: audit_dim1_path と audit_dim2_path は「該当ファイルが存在しない場合は空文字列」と定義されているが、テンプレート内で「空文字列でない場合に Read」とのみ記載されており、空文字列の場合にバリアント生成にどう影響するかが不明
- 推奨: テンプレート内で「audit パスが空の場合は knowledge.md の知見のみに基づいてバリアント生成を行う」と明記する
- impact: low, effort: low

### I-9: 条件分岐の完全性 - Phase 0 perspective 自動生成 Step 5 の再生成スキップ条件 [stability]
- 対象: SKILL.md:行106-109
- 内容: 「改善不要の場合: 現行 perspective を維持する」の判定基準が曖昧
- 推奨: 「4件の批評ファイルの全てに『重大な問題』セクションの項目が0件の場合: 再生成をスキップし現行を維持する」と明示する
- impact: low, effort: low
