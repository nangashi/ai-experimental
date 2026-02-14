### 安定性レビュー結果

#### 重大な問題

- [参照整合性: SKILL.md で定義されていない変数参照]: [phase1b-variant-generation.md] [行8-9] テンプレートは `{audit_dim1_path}`, `{audit_dim2_path}` を参照しているが、SKILL.md Phase 1B (174行) は `{audit_findings_paths}` のみを定義。変数名の不一致により実行時エラーが発生する → SKILL.md 174行を `{audit_findings_paths}` をカンマ区切りで渡すのではなく、個別の変数 `{audit_dim1_path}` (`.agent_audit/{agent_name}/audit-dim1.md` または空文字列), `{audit_dim2_path}` (`.agent_audit/{agent_name}/audit-dim2.md` または空文字列) に変更する [impact: high] [effort: low]

- [参照整合性: 参照先ファイルパスが実在しない]: [phase1a-variant-generation.md] [行10] テンプレートは `{perspective_path}` の存在確認を Read で行うが、SKILL.md Phase 0 (60行) では perspective.md は perspective-source.md から生成されるため Phase 1A 開始時点では存在しない可能性が高い → Phase 0 の perspective 解決完了後、`.agent_bench/{agent_name}/perspective.md` の生成を明示的に記載する、または phase1a-variant-generation.md の確認手順を削除する [impact: high] [effort: low]

- [条件分岐の完全性: デフォルト処理が未定義]: [SKILL.md] [Phase 0, 51-55行] reviewer パターンのフォールバック検索で、ファイル名が `*-design-reviewer` または `*-code-reviewer` に一致しない場合の処理が明示されていない → 「一致しない場合はパースペクティブ自動生成（後述）を実行する」を追加する [impact: high] [effort: low]

- [冪等性: 再実行時のファイル重複・破壊]: [SKILL.md] [Phase 1A, 144行] ベースラインが存在しない場合、ベースラインを生成して `v001-baseline.md` に保存するが、既に `v001-baseline.md` が存在する場合（Phase 1A の再実行）の処理が未定義。Write 前に Read で確認する指示がない → Phase 1A 開始前に「`.agent_bench/{agent_name}/prompts/` に既存ファイルがある場合は Phase 1B へ分岐する」を追加する [impact: high] [effort: medium]

- [出力フォーマット決定性: 返答フォーマットが未定義]: [SKILL.md] [Phase 0, 66-72行] エージェント定義が空または不足時の `AskUserQuestion` ヒアリングで、ユーザーからどのようなフォーマットで回答を得るかが未指定。構造化されていない回答では `{user_requirements}` の構成が不安定になる → AskUserQuestion の選択肢または回答フォーマット（「目的:」「入力:」「出力:」「制約:」等のフィールド）を明示する [impact: high] [effort: low]

#### 改善提案

- [指示の具体性: 曖昧表現「適切に」]: [phase2-test-document.md] [行11] 「正解キーを生成する（問題ID、検出判定基準 ○/△/× の条件、ボーナス問題リストを含む）」の「条件」が具体的でない → 「各問題に対し、検出○の条件（最低3つの具体的キーワードまたはパターン）、検出△の条件（部分検出基準）、検出×の条件を記載する」に置き換える [impact: medium] [effort: low]

- [指示の具体性: 数値基準なし]: [phase6b-proven-techniques-update.md] [行31-33] 「最も類似する2エントリをマージして1つにする」の「類似」判定基準が未定義 → 「同じVariation IDのエントリ、または独立変数が50%以上重複するエントリ」等の具体的基準を追加する [impact: medium] [effort: low]

- [出力フォーマット決定性: 区切り文字未指定]: [phase1b-variant-generation.md] [行30-32] 「独立変数: {変更内容}」の「変更内容」が複数の変更を含む場合の区切り文字（カンマ、セミコロン、改行等）が未指定 → 「変更内容（箇条書き、各項目は改行区切り）」等を明示する [impact: medium] [effort: low]

- [条件分岐の完全性: 部分失敗時の分岐不足]: [SKILL.md] [Phase 3, 229-236行] 「いずれかのプロンプトで成功結果が0回」の分岐はあるが、「全プロンプト失敗」の極端ケースの処理が明示されていない（AskUserQuestion の選択肢「中断」で対応できるが、自動中止すべきかユーザー確認すべきかが不明瞭） → 「全プロンプト失敗の場合はユーザー確認なしで中断し、Phase 3 失敗を報告する」を追加する [impact: medium] [effort: low]

- [冪等性: 再実行可能性の欠如]: [SKILL.md] [Phase 2-6] Phase 3 で一部のプロンプトが成功した後にスキルが中断された場合、再開時に Phase 3 の成功済みタスクを再実行するか、成功結果を再利用するかが未定義 → 「Phase 3 開始時、{result_path} が既に存在する場合はスキップする」等の再開ロジックを追加する [impact: medium] [effort: high]

- [参照整合性: プレースホルダと定義の不一致]: [phase5-analysis-report.md] [行6-7] `{scoring_file_paths}` を「Phase 4 で保存された採点ファイルのパス一覧」と記載しているが、パスのフォーマット（改行区切り、カンマ区切り、配列）が未指定 → SKILL.md Phase 5 (276行) で「カンマ区切りで全採点ファイルパスを {scoring_file_paths} として渡す」を追加する [impact: low] [effort: low]

- [指示の具体性: 曖昧表現「必要に応じて」]: [perspective/generate-perspective.md] [行48] 「エージェント定義入力: メタ評価レベルの問題（例: 曖昧な基準、スコープ重複、実行不可能な指示）」の「メタ評価レベル」が抽象的 → 「エージェント定義に対するメタ評価（エージェント自身の指示品質を評価する問題。例: 曖昧な評価基準の使用、複数エージェント間のスコープ重複、AI実行時に一意に解釈できない指示）」に置き換える [impact: low] [effort: low]

#### 良い点

- [出力フォーマット決定性]: phase4-scoring.md (9-12行), phase5-analysis-report.md (14-22行), phase6a-knowledge-update.md (23-25行), phase6b-proven-techniques-update.md (46-51行) で返答フォーマットが行数・フィールド名・区切り文字まで明示されている
- [参照整合性]: knowledge-init-template.md (1-7行) で全パス変数が手順内で参照され、未使用変数がない
- [冪等性]: phase6a-knowledge-update.md (16-22行) で知見の保持+統合方式が明確に定義されており、再実行時の情報破壊を防ぐ設計になっている
