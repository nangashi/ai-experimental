### 安定性レビュー結果

#### 重大な問題
- [参照整合性: audit_findings_paths 変数の未定義]: [SKILL.md] [行174] Phase 1B で audit ファイルの Glob 検索結果を `{audit_findings_paths}` として渡すと記載されているが、Phase 1B テンプレート（phase1b-variant-generation.md）は `{audit_dim1_path}` と `{audit_dim2_path}` を期待しており、変数名が不一致。phase1b-variant-generation.md 8行目で `{audit_dim1_path}`, 9行目で `{audit_dim2_path}` として定義されているが、SKILL.md では Glob で検索した全ファイルパスをカンマ区切りで渡すとある → [SKILL.md の行174を「- 個別に `{audit_dim1_path}`: `.agent_audit/{agent_name}/audit-ce.md`, `{audit_dim2_path}`: `.agent_audit/{agent_name}/audit-sa.md` として渡す（ファイル不在時は空文字列）」に修正し、テンプレートと一致させる] [impact: high] [effort: low]
- [参照整合性: 未使用パス変数 user_requirements]: [SKILL.md] [行156] Phase 1A のパス変数で `{user_requirements}` を「エージェント定義が新規作成の場合」のみ渡すとあるが、phase1a-variant-generation.md テンプレートにはこの変数プレースホルダが存在しない。エージェント新規作成時の要件情報が Phase 1A サブエージェントに伝達されない → [phase1a-variant-generation.md に `{user_requirements}` の条件付き読み込みロジックを追加するか、SKILL.md から user_requirements のパス変数記述を削除する] [impact: medium] [effort: medium]
- [条件分岐の適正化: perspective 自動生成 Step 5 の条件判定が曖昧]: [SKILL.md] [行106] 「重大な問題または改善提案がある場合」という条件で再生成を判定しているが、4件の批評それぞれが「重大な問題」「改善提案」の2セクションを持つため、どの基準で「ある」と判定するかが不明確（1件でもあればトリガーか、複数件必要か、全批評で一致が必要か）→ [「4件の批評から「重大な問題」を集計し、1件以上ある場合は perspective を再生成する。改善提案のみの場合は再生成しない」と明示する] [impact: medium] [effort: low]

#### 改善提案
- [冪等性: Phase 3 の再試行で重複ファイル生成の可能性]: [SKILL.md] [行234] Phase 3 で「再試行: 失敗したタスクのみ再実行する（1回のみ）」とあるが、result_path のファイルがすでに存在する場合（部分成功で一部タスクが保存済みの状況での再試行時）の Write 前の確認が指示されていない。再試行時に同一パスに Write で上書きされるが、冪等性の観点から Read による存在確認が推奨される → [再試行ロジックで「既存結果ファイルが存在する場合はスキップ、不在の場合のみ実行」を明示する] [impact: low] [effort: low]
- [冪等性: Phase 1A のベースラインが既存の場合の重複保存]: [SKILL.md] [行151] Phase 1A のステップ3で「ベースラインを {prompts_dir}/v001-baseline.md として Write で保存する」とあるが、すでに v001-baseline.md が存在する場合（Phase 1A の途中再実行時）の処理が未定義。既存ファイルを Read で確認せずに Write で上書きする設計 → [「v001-baseline.md が既に存在する場合はスキップ、不在時のみ保存」を明示する] [impact: low] [effort: low]
- [条件分岐の過剰: perspective 自動生成 Step 4 の critic-*.md テンプレートの既存ファイル確認]: [templates/perspective/critic-completeness.md] [行4-12] Execution Checklist（Phase 1 - Phase 4）が詳細に記述されているが、これは LLM が自然に実行できる処理手順であり、明示的な記述は過剰。品質基準の階層2「LLM 委任（プロンプトに記述しない）」に該当する → [critic テンプレートの Execution Checklist を削除し、評価基準とフォーカスエリアのみを記載する形式に簡素化する] [impact: low] [effort: medium]
- [条件分岐の過剰: phase1b テンプレートの Read 失敗時処理]: [templates/phase1b-variant-generation.md] [行8-9] audit ファイルが「指定されている場合」に Read で読み込む、とあるが、SKILL.md でのパス変数渡しロジックが不明確（空文字列を渡すのか、変数自体を省略するのか）。LLM が自然に「ファイルが存在すれば Read、不在なら無視」と処理できる設計にすべき → [SKILL.md で audit ファイルが不在の場合は変数自体を渡さない（パス変数リストから除外）か、テンプレート側で「Read 失敗時は無視して続行」を明示する] [impact: low] [effort: low]
- [指示の具体性: Phase 6 Step 1 の「推奨プロンプト」の選択肢フォーマットが曖昧]: [SKILL.md] [行303] 「推奨プロンプトの選択肢に「(推奨)」を付記」とあるが、選択肢リストのフォーマット（箇条書き形式か、カンマ区切りか、番号付きリストか）が不明確 → [「選択肢: 1) v001-baseline, 2) v001-variant-name1 (推奨), 3) v001-variant-name2 の形式で提示する」と具体化] [impact: low] [effort: low]
- [指示の具体性: Phase 0 の「必須セクション」の検証方法が曖昧]: [SKILL.md] [行110] 「必須セクション（`## 概要`, `## 評価スコープ`, ...）の存在を確認する」とあるが、セクション名の部分一致で判定するのか、完全一致か、見出しレベル（`##` vs `###`）まで厳密に確認するかが不明確 → [「見出し行に完全一致する文字列が存在するかを確認する（見出しレベル `##` 固定）」と明示する] [impact: low] [effort: low]

#### 良い点
- [条件分岐の明確性]: Phase 3, Phase 4 の部分失敗時の AskUserQuestion フォールバック（再試行/除外/中断の3択）が明確に定義されており、LLM が推測できない設計判断を適切にユーザーに委譲している
- [参照整合性の高さ]: 主要なファイルパス（approach-catalog.md, scoring-rubric.md, test-document-guide.md, proven-techniques.md, perspectives/）が全て実在し、SKILL.md とテンプレート間の大部分のパス変数が一致している
- [冪等性の配慮]: Phase 1B でバージョン番号に累計ラウンド数 + 1 を使用し、ファイル名の衝突を防ぐ設計になっている
