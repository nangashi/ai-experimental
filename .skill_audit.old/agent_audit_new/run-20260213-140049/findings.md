## 重大な問題

### C-1: 参照整合性: 未定義変数の参照 [stability]
- 対象: templates/phase1b-variant-generation.md:8-9
- 内容: {audit_dim1_path}, {audit_dim2_path} が SKILL.md のパス変数リストに定義されていない
- 推奨: SKILL.md Phase 1B の手順で Glob の結果を各パス変数名で定義し、テンプレートのパス変数リストに追記する
- impact: medium, effort: low

### C-2: データフロー: 変数名の不一致 [effectiveness, efficiency]
- 対象: SKILL.md:174, phase1b-variant-generation.md:8-9
- 内容: SKILL.md では {audit_findings_paths} として複数ファイルのパスをカンマ区切りで渡すと記述しているが、phase1b-variant-generation.md では {audit_dim1_path} と {audit_dim2_path} という個別変数を参照している。変数名の不一致により、サブエージェントが Read するかどうかの判断が不安定になる
- 推奨: SKILL.md の記述を phase1b テンプレートに合わせて {audit_dim1_path}, {audit_dim2_path} に変更するか、テンプレート側を {audit_findings_paths} のカンマ区切りパス処理に変更すべき
- impact: medium, effort: low

### C-3: 条件分岐の完全性: perspective 自動生成の再生成条件が曖昧 [stability, efficiency]
- 対象: SKILL.md:106
- 内容: 「重大な問題または改善提案がある場合」の判定基準が曖昧。批評結果のどのフィールドをどう判定するかが未定義。批評が4件ある中でどちらか1件でも該当すれば実行されるが、複数批評の合意形成ステップが不在のため、再生成の是非判断にサブエージェント呼び出しのコンテキストが無駄になる可能性がある
- 推奨: 「4件の批評の Critical Issues セクションに1件でもエントリがあれば再生成」のように具体的な条件を明示する
- impact: medium, effort: low

### C-4: 冪等性: Phase 0 の perspective 自動生成で再実行時の上書き挙動が未定義 [stability]
- 対象: SKILL.md:79-112
- 内容: perspective-source.md が既に存在する場合の処理が未定義。再実行時に上書きされるか、スキップされるか不明
- 推奨: Step 1 の前に「既に {perspective_source_path} が存在する場合は自動生成をスキップする」を追加
- impact: medium, effort: low

### C-5: データフロー: Phase 6 Step 2C の完了待機 [effectiveness]
- 対象: SKILL.md:330-352
- 内容: SKILL.md line 352 で「B) スキル知見フィードバックサブエージェントの完了を待ってから」と記述されているが、Step 2B（proven-techniques 更新）と Step 2C（次アクション選択）は line 330-352 で「同時に実行する」と指示されている。同時起動した Step 2C が Step 2B の完了を待つのは不可能
- 推奨: Step 2C を Step 2B の完了後に実行する記述に変更すべき
- impact: medium, effort: low

## 改善提案

### I-1: 外部スキルディレクトリへの参照 [architecture]
- 対象: SKILL.md:54, SKILL.md:74
- 内容: `.claude/skills/agent_bench/perspectives/{target}/{key}.md` および `.claude/skills/agent_bench/perspectives/design/*.md` への参照は agent_bench_new 外のファイル
- 推奨: パースペクティブのフォールバック検索は agent_bench_new 内の perspectives ディレクトリに変更するか、この外部参照を意図的なものとして明示する。スキル内へのコピーまたはパス変数化を推奨
- impact: medium, effort: low

### I-2: Phase 4 の採点詳細保存の必要性 [efficiency]
- 対象: phase4-scoring.md:8
- 内容: 詳細な採点結果を scoring ファイルに保存するが、このファイルは Phase 5 で report 作成時に再度 Read される。report 作成時に改めて scoring ファイルを精査するなら、採点サブエージェントの返答は最小限（2行サマリ）で十分。現状では Phase 5 で全 scoring ファイルを Read するコンテキスト消費が発生する
- 推奨: 採点詳細保存の目的が監査・デバッグ用ならその旨を明記すべき
- impact: medium, effort: low

### I-3: 参照整合性: 外部ディレクトリへの参照 [stability]
- 対象: SKILL.md:54
- 内容: `.claude/skills/agent_bench/perspectives/{target}/{key}.md` への参照は `agent_bench_new` ディレクトリ外を参照している
- 推奨: パースペクティブのフォールバック検索は `agent_bench_new` 内の perspectives ディレクトリに変更するか、この外部参照を意図的なものとして明示する
- impact: low, effort: low

### I-4: 外部ディレクトリへの参照の依存関係明示 [architecture]
- 対象: SKILL.md:174
- 内容: `.agent_audit/{agent_name}/audit-*.md` への参照は agent_bench_new のスコープ外
- 推奨: この参照は機能統合の観点から必要と思われるが、依存関係を明示的にドキュメント化することを推奨
- impact: low, effort: low

### I-5: テンプレート内の外部ディレクトリ参照 [architecture]
- 対象: phase1b-variant-generation.md:8-9
- 内容: テンプレート内に外部ディレクトリへの参照（`.agent_audit/{agent_name}/audit-*.md`）が記載されている
- 推奨: この参照は SKILL.md で渡されるパス変数 `{audit_findings_paths}` に置き換えることで、テンプレートをスキル外依存から分離できる
- impact: low, effort: low

### I-6: Phase 2 での perspective_path と perspective_source_path の二重 Read [efficiency]
- 対象: phase2-test-document.md:4-6
- 内容: perspective.md（問題バンク除外版）と perspective-source.md（問題バンク含む版）の両方を Read する。perspective.md は採点時のバイアス防止用だが、Phase 2 のテスト文書生成では問題バンクが必要なため、perspective-source.md のみで十分
- 推奨: perspective.md の Read は不要
- impact: low, effort: low

### I-7: 曖昧表現: 「最も類似する」の判定基準が未定義 [stability]
- 対象: templates/phase6b-proven-techniques-update.md:36
- 内容: 「最も類似する2エントリをマージ」の類似性判定基準が曖昧
- 推奨: 「効果範囲が重複するエントリ」「同一カテゴリ内のエントリ」など具体的な類似性基準を追加
- impact: low, effort: low

### I-8: 曖昧表現: 「エビデンスが最も弱い」の判定基準が未定義 [stability]
- 対象: templates/phase6b-proven-techniques-update.md:40
- 内容: 「エビデンスが最も弱いエントリ」の判定基準が不明
- 推奨: 「出典が最も少ない」「|effect| が最小」など具体的な基準を追加
- impact: low, effort: low
