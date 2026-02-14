## 重大な問題

### C-1: 未定義変数参照 [stability]
- 対象: templates/phase1-dimension-analysis.md:14
- 内容: `{dim_path}` が手順内で参照されているが、パス変数リストで定義されていない
- 推奨: パス変数リストに `{dim_path}` を追加するか、手順の表現を「分析エージェント定義ファイル（SKILL.md で指定された次元パス）」等に修正する
- impact: medium, effort: low

### C-2: findings ファイル集計の Grep パターン誤り [stability]
- 対象: SKILL.md:203-205
- 内容: Grep パターン `"^\### "` で見出しを検索しているが、Markdown の見出しは `###` の直後にスペースを1つのみ持つため、`^\###` ではなく `^###` とすべき
- 推奨: Grep パターンを `"^### .* \[severity: critical\]"` に修正する
- impact: high, effort: low

### C-3: 外部スキル参照 [architecture]
- 対象: SKILL.md:24, analysis.md:23-27
- 内容: agent_bench サブディレクトリが agent_audit_new スキル内に存在し、スキルディレクトリ外（.claude/skills/agent_bench/）のファイルへの依存が混在している
- 推奨: 外部依存による構造不安定性。agent_bench は独立スキルとして分離すべき
- impact: high, effort: high

## 改善提案

### I-1: Phase 1 サブエージェント返答解析の冗長性 [efficiency]
- 対象: SKILL.md:202-206
- 内容: Phase 1完了後にfindings件数をGrepで個別抽出する処理。Bashでの3回のgrep実行が必要で、各次元ごとに9回のGrep呼び出しが発生する（3-5次元で27-45コール）
- 推奨: サブエージェントがfindingsファイル保存時にヘッダ行に `Total: N (critical: C, improvement: I, info: K)` を出力し、Phase 1で先頭10行のみReadすることで置換可能（約50-100トークン節約/次元）
- impact: medium, effort: low

### I-2: サマリヘッダ抽出の曖昧性 [stability]
- 対象: SKILL.md:221
- 内容: 「サマリヘッダ（`Total: {N} (critical: {C}, improvement: {I}, info: {K})`）を抽出する」と記載されているが、抽出方法（Grep パターン、行番号等）が不明確
- 推奨: 抽出方法を明示する（例: 「先頭10行内で `Total:` で始まる行を検索し、該当行から件数を抽出する」）
- impact: medium, effort: low

### I-3: apply-improvements 返答の解析可能性 [stability]
- 対象: SKILL.md:300
- 内容: 「返答内容（変更サマリ）をテキスト出力する」とあるが、返答フォーマット（modified/skipped リスト）の解析が必要な箇所（Phase 3 での変更詳細表示）で、解析方法が明示されていない
- 推奨: 「apply-improvements サブエージェントの返答を {changes_summary} 変数に記録し、Phase 3 でそのまま表示する」と明示する
- impact: medium, effort: low

### I-4: group-classification.md の統合不完全 [architecture]
- 対象: SKILL.md:84-102
- 内容: Phase 0でGrepパターン検出とグループ判定ロジックをインライン記述しているが、resolved-issues.md（I-8）の対応では「group-classification.md内容をSKILL.mdに埋め込み」と記載されている。group-classification.mdはファイルとして残存しており、統合が完全に実行されていない
- 推奨: group-classification.mdの内容が完全にSKILL.mdに統合されている場合、そのファイルは削除すべき。残存する場合は二重管理になる
- impact: medium, effort: low

### I-5: Phase 1 サブエージェントプロンプトの不完全な外部化 [architecture]
- 対象: templates/phase1-dimension-analysis.md:14
- 内容: テンプレート内で「分析エージェント定義ファイル（`{dim_path}`）を Read で読み込む」と指示しているが、`{dim_path}` 変数がこのテンプレートのパス変数セクションに定義されていない
- 推奨: SKILL.md 162-169行目でパス変数として dim_path を渡しているが、テンプレート側のパス変数セクションに未記載。サブエージェント側で変数が未定義と誤認される可能性がある
- impact: medium, effort: low

### I-6: Phase 2 Step 2a: Per-item承認のテキスト出力量 [efficiency]
- 対象: SKILL.md:242-252
- 内容: 各finding全文をテキスト出力するため、親コンテキストに findings の全内容が蓄積される。10件の findings があると約2000-3000トークンが親コンテキストに残る
- 推奨: Step 2a開始時に「findings詳細は `.agent_audit/{agent_name}/audit-{ID}.md` で確認できます。各findingのID/severity/titleのみを表示し、詳細は確認時にRead」する設計に変更することで大幅にコンテキスト節約可能
- impact: medium, effort: medium

### I-7: Phase 2 Step 3 成果物構造検証の欠落 [architecture]
- 対象: SKILL.md:305-316
- 内容: Phase 2検証ステップで audit-approved.md の構造検証を実施しているが、検証対象の成果物は「改善適用後のエージェント定義ファイル」であり、audit-approved.mdは承認記録である。最終成果物であるエージェント定義ファイルの構造検証が主目的だが、構造検証項目が最小限（frontmatter, description フィールドのみ）で、エージェント定義固有の必須セクション（手順、評価基準、出力フォーマット等）の検証が欠落している
- 推奨: 改善適用後のエージェント定義ファイルが正しい構造を維持しているか確認する検証項目を拡充すべき（例: セクション見出し階層、ツール名参照の一貫性、パス変数定義の完全性等）
- impact: medium, effort: medium

### I-8: Phase 1 サブエージェント返答フォーマット検証の欠落 [effectiveness]
- 対象: Phase 1 エラーハンドリング
- 内容: Phase 1のサブエージェント成否判定を「findingsファイルの存在」のみで行っているが、サブエージェントが `error: {概要}` を返答した場合の処理が記述されていない
- 推奨: サブエージェント返答を解析して成否を判定する記述を追加すると、失敗原因を親コンテキストで把握できる（例: 「{次元名}の分析に失敗しました: {エラー概要}」）
- impact: medium, effort: low

### I-9: Phase 1 部分失敗時の続行判定の曖昧性 [stability]
- 対象: SKILL.md:193
- 内容: 「成功した次元で続行します」とあるが、成功数がゼロの場合と1以上の場合で処理が分岐していない（実際は全失敗=エラー終了のため問題ないが、フロー上の不明確さが残る）
- 推奨: 「成功数 > 0 の場合は成功した次元で Phase 2 へ進む」と明示する
- impact: low, effort: low
