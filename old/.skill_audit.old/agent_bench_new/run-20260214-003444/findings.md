## 重大な問題

### C-1: Phase 6 Step 2C 実行条件の暗黙的依存 [stability]
- 対象: SKILL.md:368 (Phase 6 Step 2C)
- 内容: 「A) と B) の両方が完了したことを確認した上で」という記述があるが、完了確認の具体的手段が未定義。サブエージェントタスクの完了をどのように検知するかが曖昧
- 推奨: 「A) と B) のサブエージェントタスクの完了を Task ツールの返答で確認し、その後 AskUserQuestion で次アクション選択を実施する」と明記
- impact: high, effort: low

### C-3: Phase 0 perspective フォールバック パス構成の暗黙的依存 [stability]
- 対象: SKILL.md:66 (Phase 0 Step 2)
- 内容: フォールバックパス `.claude/skills/agent_bench_new/perspectives/{target}/{key}.md` の構成が暗黙的。`{key}` が `-design-reviewer` または `-code-reviewer` の前の部分という導出ロジックは記述されているが、実際のパス構成例が不明瞭
- 推奨: 「例: `security-design-reviewer` → `{key}` = `security`, `{target}` = `design` → `.claude/skills/agent_bench_new/perspectives/design/security.md`」と具体例を追記
- impact: medium, effort: low

### C-4: Phase 0 Step 2 既存 perspective 参照データ収集の暗黙的フォールバック [stability]
- 対象: SKILL.md:86-88 (Phase 0 Step 2)
- 内容: 「見つからない場合は `{reference_perspective_path}` を空とする」とあるが、Step 3 のサブエージェント指示で空の場合の動作が未定義
- 推奨: templates/perspective/generate-perspective.md の手順1で「{reference_perspective_path} が空の場合は Read をスキップし、構造参照なしで生成する」と明記
- impact: medium, effort: low

### C-5: Phase 5 の「スコアサマリのみ使用」の具体的範囲未定義 [stability, efficiency]
- 対象: templates/phase5-analysis-report.md:9
- 内容: 「スコアサマリのみを使用」とあるが、具体的にどのフィールド（Mean/SD/Run1/Run2/検出スコア/bonus/penalty）を参照するかが不明。サブエージェントに指示の明確化が必要
- 推奨: 「各採点結果ファイルから以下のフィールドのみを抽出: Mean, SD, Run1スコア, Run2スコア。問題別の検出マトリクスやボーナス/ペナルティ詳細は参照しない」と明記
- impact: medium, effort: low

## 改善提案

### I-1: Phase 1A user_requirements 参照の条件分岐 [effectiveness, stability]
- 対象: SKILL.md:175-176 (Phase 1A), templates/phase1a-variant-generation.md:9
- 内容: SKILL.md で「エージェント定義が新規作成の場合: {user_requirements}」と記載されているが、テンプレート側では無条件に参照。agent_path が存在する場合は {user_requirements} が渡されない可能性があり、データフロー不整合のリスクがある
- 推奨: テンプレート側で条件分岐を追加するか、SKILL.md で「{user_requirements} を常に渡す（空文字列可）」と明示
- impact: medium, effort: low

### I-2: Phase 3 直接指示の外部化 [architecture]
- 対象: SKILL.md:235-242 (Phase 3)
- 内容: 評価実行サブエージェントに7行の直接指示を渡している。パターン一貫性のためテンプレートファイルへの外部化を推奨
- 推奨: templates/phase3-evaluation.md を作成し、直接指示を外部化
- impact: medium, effort: low

### I-3: Phase 6 Step 1 直接指示の外部化 [architecture]
- 対象: SKILL.md:328-335 (Phase 6 Step 1)
- 内容: デプロイサブエージェントに8行の直接指示を渡している。パターン一貫性のためテンプレートファイルへの外部化を推奨
- 推奨: templates/phase6a-deploy.md を作成し、直接指示を外部化
- impact: medium, effort: low

### I-4: Phase 1B Deep モード時のカタログ読込み条件 [efficiency, architecture]
- 対象: SKILL.md:191, templates/phase1b-variant-generation.md:17
- 内容: SKILL.md は全てのケースで approach_catalog_path をパス変数として渡しているが、テンプレートは「Deep モード選択時のみ Read」と記述。パス変数が渡されている時点で期待動作が曖昧になる
- 推奨: Deep モード時のみ必要であることをテンプレートが明記している以上、親が条件分岐してパス変数を渡すか、テンプレートが Broad/Deep 判定後に条件付き Read を行うべき
- impact: medium, effort: medium

### I-5: Phase 0 Step 4 批評結果の統合をサブエージェント内で実行 [efficiency]
- 対象: SKILL.md:120-122 (Phase 0 Step 4)
- 内容: Phase 0 Step 5 で4件全てを Read で読み込み統合する必要がある。フィードバック統合ロジックを critic-completeness サブエージェント内で実行し、統合結果のみ返答させる方式に変更すれば、3件のファイル Read を削減できる
- 推奨: critic-completeness テンプレートを修正し、4件の批評ファイルを読み込んで統合結果のみ返答させる
- impact: medium, effort: medium

### I-6: Phase 1B の「agent_audit 分析結果を考慮」の具体的処理方法未定義 [stability]
- 対象: templates/phase1b-variant-generation.md:8-12
- 内容: 「基準有効性・スコープ整合性の改善推奨を考慮」とあるが、どのセクションを参照し、どう反映するかが曖昧
- 推奨: 「各ファイルの「改善提案」セクションを読み込み、提案内容を perspective.md のスコープ項目・問題バンクのギャップ分析に反映する」と具体化
- impact: medium, effort: low

### I-7: Phase 0 perspective.md 重複書込みの冪等性保証 [architecture]
- 対象: SKILL.md:72 (Phase 0 Step 4a)
- 内容: perspective.md の存在確認後、「存在しない場合のみ」Write で保存するとあるが、同一ラウンドで再実行時に Read → Write が複数回発生する可能性がある。冪等性保証のロジックが不明確
- 推奨: 「Step 4a で Read 確認済みの場合、後続ステップで再 Read せず結果を保持する」旨を明記
- impact: low, effort: low

### I-8: Phase 2 の「knowledge.md のテストセット履歴セクションのみ参照」の参照目的未定義 [efficiency, stability]
- 対象: templates/phase2-test-document.md:7
- 内容: 「テストセット履歴」セクション参照と記載があるが、何のために参照するか（多様性確保のため過去ドメインを避ける）が暗黙的
- 推奨: 「{knowledge_path} （「テストセット履歴」セクションのみを参照し、過去ラウンドと異なるドメインを選択して多様性を確保する）」と目的を明記
- impact: low, effort: low

### I-9: Phase 6 Step 2B の「類似度判定・エビデンス強度の具体的基準」がテンプレート内に未反映 [stability]
- 対象: templates/phase6b-proven-techniques-update.md:37
- 内容: resolved-issues.md で「具体的基準を明示」と記録されているが、テンプレート本文には反映されていない
- 推奨: テンプレートの統合ルールセクションに「類似度判定: (1) Variation ID のカテゴリ（S/C/N/M）が同一、(2) 効果範囲の記述に共通キーワード（見出し/粒度/例示/形式）が2つ以上含まれる」と明記
- impact: low, effort: low

---
注: 改善提案を 3 件省略しました（合計 12 件中上位 9 件を表示）。省略された項目は次回実行で検出されます。
