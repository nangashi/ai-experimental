### 安定性レビュー結果

#### 重大な問題
なし

#### 改善提案
- [参照整合性: Phase 0 Step 7a の audit-*.md パターンで resolved-issues.md も削除される]: [SKILL.md] [Line 114] [`rm -f .agent_audit/{agent_name}/audit-*.md` は resolved-issues.md も削除してしまう] → [パターンを明示: `rm -f .agent_audit/{agent_name}/audit-CE.md .agent_audit/{agent_name}/audit-IC.md .agent_audit/{agent_name}/audit-SA.md .agent_audit/{agent_name}/audit-DC.md .agent_audit/{agent_name}/audit-WC.md .agent_audit/{agent_name}/audit-OF.md .agent_audit/{agent_name}/audit-approved.md` または `rm -f .agent_audit/{agent_name}/run-*/audit-*.md` のように run ディレクトリ配下に限定] [impact: medium] [effort: low]
- [条件分岐: Phase 2 Step 3 で承認数が 0 の場合のフォールバックが不完全]: [SKILL.md] [Line 271] [承認数 0 の場合に Phase 3 へ直行するが、Phase 3 では「Phase 2 が実行された場合」の出力フォーマットを使用する指示がなく、承認数 0 のケースが Phase 3 の分岐に含まれていない] → [Phase 2 が実行されたが承認数が 0 の場合の Phase 3 出力フォーマットを追加: `Phase 2 が実行され承認数が 0 の場合: 「- エージェント: {agent_name}\n- 検出: critical {N}件, improvement {M}件\n- 承認: 0件（全てスキップ）」と出力`] [impact: low] [effort: low]
- [参照整合性: Phase 1 の ID_PREFIX マッピングに dim_path との対応が暗黙的]: [SKILL.md] [Line 161-172] [dim_path（例: evaluator/criteria-effectiveness）から ID_PREFIX（例: CE）への導出ルールが記述されていない。antipattern_catalog_path のマッピングテーブルには ID_PREFIX → カタログパスのみ記載] → [dim_path → ID_PREFIX のマッピングテーブルを追加: `shared/instruction-clarity → IC`, `evaluator/criteria-effectiveness → CE`, `evaluator/scope-alignment → SA`, `evaluator/detection-coverage → DC`, `producer/workflow-completeness → WC`, `producer/output-format → OF`, `unclassified/scope-alignment → SA`] [impact: medium] [effort: low]
- [出力フォーマット決定性: Phase 1 サブエージェント prompt 内の返答フォーマット指示が不完全]: [SKILL.md] [Line 158] [「以下の1行フォーマット**のみ**で返答」とあるが、エラー発生時の返答フォーマットが未定義。サブエージェントが例外時に複数行の詳細を返す可能性がある] → [エラー時の返答フォーマットを追加: `エラー発生時は: error: {次元名}, reason: {エラー概要1行}` のように明示] [impact: medium] [effort: low]
- [冪等性: Phase 0 Step 7a で出力ディレクトリのクリーンアップが不完全]: [SKILL.md] [Line 114] [audit-*.md のみ削除するが、run-{timestamp}/ のような run ディレクトリ構造が存在する場合にそれらのファイルが削除されない。analysis.md も残る] → [Phase 0 の初期化処理で `.agent_audit/{agent_name}/run-*` ディレクトリが存在する場合の処理方針を明示（最新 N 個を保持して古いものを削除、または全削除等）] [impact: low] [effort: medium]
- [条件分岐: Phase 0 Step 3 で frontmatter 検証の else 節（「いいえ」選択時）の終了処理が曖昧]: [SKILL.md] [Line 80] [「いいえ」の場合は終了する」とあるが、終了時のメッセージ内容やエラーコードの指定がない] → [終了時のメッセージを明示: `「いいえ」選択時は「中止しました。」とテキスト出力して終了する`] [impact: low] [effort: low]
- [参照整合性: Phase 2 Step 2 の findings ファイル読み込み指示が抽出方法のみで Read 実行の明示がない]: [SKILL.md] [Line 209] [「findings ファイルを Read し、各 finding の ID, severity, title を抽出する」とあるが、Phase 1 で成功した全次元の findings ファイルを順次 Read するのか、必要に応じて Read するのかが不明確] → [Read 実行を明示: `Phase 1 で成功した全次元の findings ファイルを順次 Read し、全 findings を収集する。各 finding の抽出方法:`] [impact: low] [effort: low]

#### 良い点
- [冪等性]: Phase 0 Step 7a で既存の findings ファイルを削除する処理が明示されており、再実行時の重複を防ぐ設計が確認できた
- [出力フォーマット決定性]: Phase 1 サブエージェントの返答フォーマットが1行に固定されており、親コンテキストの肥大化を防ぐ設計が確認できた
- [参照整合性]: SKILL.md で使用される全プレースホルダ変数（agent_path, agent_name, findings_save_path, antipattern_catalog_path, approved_findings_path, backup_path 等）が適切に定義・解決されており、テンプレート内の変数も整合している
