## 重大な問題

### C-1: agent_bench ディレクトリの存在 [architecture]
- 対象: SKILL.md および分析 output
- 内容: agent_audit_new スキル内に agent_bench スキル全体（SKILL.md、templates/、perspectives/ 等）が配置されており、ファイルスコープ違反となっている
- 推奨: agent_bench ディレクトリ全体を削除する
- impact: high, effort: low

## 改善提案

### I-1: Phase 2 Step 3-4間の改善適用確認の追加 [ux]
- 対象: Phase 2 Step 3-4間
- 内容: Phase 2 Step 3で承認結果を保存した後、Step 4の改善適用前に確認がない。ユーザーはfindingsを承認しただけで、即座のファイル書き込みまでは意図していない可能性がある
- 推奨: Step 4の改善適用前に「{N}件の改善をエージェント定義ファイルに適用します。実行しますか？」のAskUserQuestion確認を追加する。選択肢は「今すぐ適用」「後で手動適用（承認結果はaudit-approved.mdに保存済み）」「キャンセル」の3択
- impact: medium, effort: low

### I-2: Phase 0 Step 7a の audit-*.md パターンで resolved-issues.md も削除される [stability]
- 対象: SKILL.md Line 114
- 内容: `rm -f .agent_audit/{agent_name}/audit-*.md` は resolved-issues.md も削除してしまう
- 推奨: パターンを明示: `rm -f .agent_audit/{agent_name}/audit-CE.md .agent_audit/{agent_name}/audit-IC.md .agent_audit/{agent_name}/audit-SA.md .agent_audit/{agent_name}/audit-DC.md .agent_audit/{agent_name}/audit-WC.md .agent_audit/{agent_name}/audit-OF.md .agent_audit/{agent_name}/audit-approved.md` または `rm -f .agent_audit/{agent_name}/run-*/audit-*.md` のように run ディレクトリ配下に限定
- impact: medium, effort: low

### I-3: Phase 1 の ID_PREFIX マッピングに dim_path との対応が暗黙的 [stability]
- 対象: SKILL.md Line 161-172
- 内容: dim_path（例: evaluator/criteria-effectiveness）から ID_PREFIX（例: CE）への導出ルールが記述されていない。antipattern_catalog_path のマッピングテーブルには ID_PREFIX → カタログパスのみ記載
- 推奨: dim_path → ID_PREFIX のマッピングテーブルを追加: `shared/instruction-clarity → IC`, `evaluator/criteria-effectiveness → CE`, `evaluator/scope-alignment → SA`, `evaluator/detection-coverage → DC`, `producer/workflow-completeness → WC`, `producer/output-format → OF`, `unclassified/scope-alignment → SA`
- impact: medium, effort: low


### I-5: Phase 1 返答フォーマットの軽量化 [architecture]
- 対象: SKILL.md:158, 177-178
- 内容: 返答フォーマットが `dim: {次元名}, critical: {N}, improvement: {M}, info: {K}` と指定されているが、返答解析失敗時にファイル存在確認にフォールバックするロジックがある
- 推奨: 返答フォーマットを完全に廃止し、ファイル存在確認のみで成否判定する設計に統一する
- impact: medium, effort: medium

### I-6: データフロー最適化: Phase 1返答解析の簡素化 [effectiveness]
- 対象: Phase 1, lines 176-182
- 内容: 現在の設計では返答解析とファイル存在確認の二重判定を行っている
- 推奨: 「findings ファイルの存在のみで成否判定」に統一し、返答解析ロジック（dim:抽出、フォーマット不正処理）を削除することで、コンテキスト節約とエラーハンドリング簡素化が同時に達成できる
- impact: medium, effort: medium

### I-7: Phase 2 Step 2 findings 抽出の効率化 [efficiency]
- 対象: SKILL.md 行209-214
- 内容: findings ファイルから ID/severity/title を抽出する際、親が全 findings を Read してパースしている。findings が多数の場合、コンテキスト負荷が高い
- 推奨: findings ファイルに finding 件数サマリをヘッダに記載し、親は件数のみ取得する。Per-item 承認時に逐次 Read
- impact: medium, effort: low

### I-8: 長いインラインブロック（Phase 1） [architecture]
- 対象: SKILL.md:146-159
- 内容: 14行のサブエージェントプロンプトがインラインで記述されている
- 推奨: テンプレートファイルへの外部化を推奨
- impact: medium, effort: low

### I-9: Phase 2 Step 3 で承認数が 0 の場合のフォールバックが不完全 [stability]
- 対象: SKILL.md Line 271
- 内容: 承認数 0 の場合に Phase 3 へ直行するが、Phase 3 では「Phase 2 が実行された場合」の出力フォーマットを使用する指示がなく、承認数 0 のケースが Phase 3 の分岐に含まれていない
- 推奨: Phase 2 が実行されたが承認数が 0 の場合の Phase 3 出力フォーマットを追加: `Phase 2 が実行され承認数が 0 の場合: 「- エージェント: {agent_name}\n- 検出: critical {N}件, improvement {M}件\n- 承認: 0件（全てスキップ）」と出力`
- impact: low, effort: low
