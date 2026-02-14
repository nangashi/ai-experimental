### 安定性レビュー結果

#### 重大な問題
- [E. 参照整合性: analysis.md 参照の未定義ケース処理が不完全]: [SKILL.md] [行319-322] Phase 2 検証ステップで analysis.md が存在しない場合の外部参照整合性検証はスキップするが、存在する場合の Read 失敗時の処理が未定義 → [検証ステップで Read 前にファイル存在確認を追加し、Read 失敗時はスキップではなく警告を出力する処理を明示する。例: "Read 失敗時: 「⚠ 警告: analysis.md の読み込みに失敗しました。外部参照整合性検証をスキップします」とテキスト出力し、検証は継続"] [impact: medium] [effort: low]
- [A. 指示の具体性: 曖昧な判定基準]: [SKILL.md] [行194] 「必須次元」の定義が暗黙的。「IC 次元が失敗 かつ 成功数 = 1」という条件は明示されているが、なぜ IC が必須なのかが説明されていない → [Phase 0 で「IC（指示明確性）は全グループで共通の必須次元です」と明示し、Phase 1 の中止条件説明を「IC は全エージェントの基盤となる次元であるため、IC 失敗+他1次元のみ成功の場合は分析精度が不十分と判断し中止します」と具体化する] [impact: medium] [effort: low]
- [D. 冪等性: findings ファイル上書き時の情報欠損リスク]: [SKILL.md] [行156-158] Phase 1 で既存 findings ファイルを上書きする際、過去の分析結果が消失するが、ユーザーが中断・再実行した場合のデータ復旧方法が提示されていない → [上書き前に既存ファイルを .agent_audit/{agent_name}/audit-{ID_PREFIX}.md.prev にバックアップし、「⚠ 既存の findings ファイル {M}件を上書きします（バックアップ: .prev 拡張子で保存）」とテキスト出力する処理を追加] [impact: medium] [effort: low]
- [C. 条件分岐の完全性: Phase 2 Step 1 失敗時の処理が未定義]: [SKILL.md] [行89, 257] analysis.md に「Phase 2 Step 1 失敗: 未定義（SKILL.md に記載なし）」とあるが、SKILL.md にも処理フローの記載がない。findings 収集失敗時の処理が未定義 → [Phase 2 Step 1 のサブエージェント完了後に、findings-summary.md の存在確認と Read 成否を判定する処理を追加。失敗時: 「✗ エラー: findings の収集に失敗しました: {エラー詳細}\nPhase 1 で生成された findings ファイルを手動で確認してください: .agent_audit/{agent_name}/audit-*.md」とエラー出力し、処理を終了する] [impact: high] [effort: low]
- [C. 条件分岐の完全性: Fast mode の部分失敗時の扱いが未定義]: [SKILL.md] [行93, 195-199] Phase 0 で fast_mode フラグを設定するが、Phase 1 部分失敗時の継続確認（AskUserQuestion）が Fast mode でスキップされるかが不明 → [Phase 1 の部分失敗判定後、Fast mode 時の処理を明示: 「{fast_mode} が true の場合、継続確認をスキップし、成功次元のみで自動的に Phase 2 へ進む（テキスト出力: "Fast mode: {成功数}次元で Phase 2 へ自動継続します"）。{fast_mode} が false の場合、AskUserQuestion で継続/中止をユーザーに確認する」] [impact: high] [effort: low]

#### 改善提案
- [A. 指示の具体性: 曖昧表現「必要時」]: [agents/shared/instruction-clarity.md] [行72] "Only evaluate definition-level references" の判定基準が曖昧。"definition-level" と "workflow step" の境界が明示されていない → ["definition-level references" を具体化: "Overview/Task/手順/前提条件セクション内で言及されるファイル・テンプレート参照で、{variable} 形式のパス変数を使わない参照（例: 「refer to the template」）。ワークフロー内の「Step 1: Read {template_path}」のような変数参照は WC 次元が担当"] [impact: medium] [effort: low]
- [A. 指示の具体性: 件数抽出失敗時の再取得方法が不明確]: [SKILL.md] [行183] 「Phase 2 Step 1 で findings ファイルから直接件数を再取得する」とあるが、再取得の具体的な方法（Grep パターン、集計ロジック）が未定義 → [Phase 2 Step 1 のサブエージェント prompt に再取得ロジックを追記: 「Phase 1 で件数取得失敗した次元がある場合、findings ファイルを Read し、severity 行（`- severity: critical/improvement`）を Grep で抽出して集計してください」] [impact: low] [effort: low]
- [B. 出力フォーマット決定性: サブエージェント返答行数の曖昧さ]: [templates/apply-improvements.md] [行36] 「以下のフォーマットで**結果のみ**返答する（上限: 30行以内）」とあるが、30行を超えた場合の動作が未定義 → ["30行を超える場合は、変更概要を省略し、finding ID と変更種別（追加/修正/削除/統合）のみ記載する。詳細は audit-approved.md を参照するよう促す" と明示] [impact: low] [effort: low]
- [E. 参照整合性: テンプレート内プレースホルダの未使用変数]: [templates/apply-improvements.md] [行4] `{backup_path}` がテンプレート本文（手順セクション）で使用されていない。パス変数として定義されているが、実際の改善適用処理で参照されていない → [手順 2 または 3 に「バックアップパス {backup_path} が存在することを確認し、変更適用中のエラー発生時は復旧可能であることを認識する」といった参照を追加するか、または手順内で明示的に使用しない場合はパス変数リストから削除] [impact: low] [effort: low]
- [A. 指示の具体性: 「例外情報抽出の順序」の優先度が曖昧]: [SKILL.md] [行184-187] Phase 1 のエラーハンドリングで例外情報を抽出する順序が記載されているが、「抽出失敗時」の判定基準が不明確 → [抽出失敗条件を明示: "1. 'Error:' または 'Exception:' を含む行が存在しない場合 → 2. へ。2. 最初の段落が空（Task 返答が完全に空、または最初の100文字が空白のみ）の場合 → 3. へ"] [impact: low] [effort: low]
- [D. 冪等性: バックアップファイル名の衝突リスク]: [SKILL.md] [行291] バックアップファイル名が `{agent_path}.backup-$(date +%Y%m%d-%H%M%S)` だが、1秒以内に複数回実行した場合に衝突する可能性がある → [date コマンドに %N（ナノ秒）を追加: `{agent_path}.backup-$(date +%Y%m%d-%H%M%S-%N)` として衝突リスクを低減する。または、既存バックアップファイル存在時は連番サフィックス（-2, -3 等）を付与する] [impact: low] [effort: low]
- [C. 条件分岐の完全性: validation_failed フラグ未初期化]: [SKILL.md] [行322, 345] `{validation_failed}` フラグが検証失敗時に true に設定されるが、Phase 2 開始時の初期化（false 設定）が明示されていない → [Phase 2 冒頭で「`{validation_failed} = false` を初期化する」と明記する] [impact: low] [effort: low]

#### 良い点
- [B. 出力フォーマット決定性]: Phase 1, Phase 2 Step 1, Phase 2 Step 4 の全サブエージェント返答フォーマットが行数・フィールド名・区切り文字まで明示されており、パース可能性が高い（SKILL.md 行169-175, 250-255, templates/apply-improvements.md 行36-42）
- [E. 参照整合性]: 全ての外部参照ファイル（group-classification.md, detection-process-common.md, 次元エージェントファイル、テンプレート）が analysis.md で検証済みであり、スキルディレクトリ内に実在している
- [D. 冪等性]: Phase 2 Step 4 でバックアップ作成→改善適用→検証の順序が明確で、エラー時の復旧コマンドが具体的に提示されている（SKILL.md 行291-307）
