## 重大な問題

### C-1: 参照整合性: ファイル不在時の挙動 [stability]
- 対象: SKILL.md:64
- 内容: `group-classification.md` を参照しているが、このファイルが存在しない場合の処理（エラー終了、スキップ、組み込みルールで継続）が未定義
- 推奨: 「スキル内部ファイルが不在の場合はエラー終了する」と明記する
- impact: high, effort: low

### C-2: 参照整合性: プレースホルダの未定義 [stability]
- 対象: SKILL.md:244-247
- 内容: Task promptでテンプレートに渡す `{approved_findings_path}` が、apply-improvements.mdでは定義されているが、SKILL.md内のパス変数リスト（行8-13の「## パス変数」セクションに該当する箇所が存在しない）に記載されていない
- 推奨: SKILL.mdに「パス変数」セクションを追加し、全プレースホルダを明示的に定義する
- impact: medium, effort: low

### C-3: 冪等性: 再実行時の状態破壊 [stability]
- 対象: SKILL.md:81
- 内容: 出力ディレクトリ作成 `mkdir -p .agent_audit/{agent_name}/` のみ記載があり、既存ディレクトリがある場合の挙動（上書き、スキップ、エラー）が未定義
- 推奨: 「既存ディレクトリが存在する場合はそのまま使用する」と明記し、既存ファイル（findings, approved）の扱いを定義する
- impact: medium, effort: low

### C-4: 条件分岐の完全性: デフォルト処理の欠落 [stability]
- 対象: SKILL.md:227-231
- 内容: 改善適用の確認でキャンセル選択時の処理は記載されているが、AskUserQuestionの返答タイムアウトや不正入力時の処理が未定義
- 推奨: タイムアウト/不正入力時は「キャンセル」として扱うことを明記する
- impact: medium, effort: low

### C-5: 出力フォーマット決定性: サブエージェント返答の不完全検証 [stability]
- 対象: SKILL.md:125
- 内容: 返答バリデーションで「フォーマット不正時は件数を '?' として表示」とあるが、'?' を保持したまま後続処理（Phase 2のソート、一覧表示）で数値演算や比較が必要な場合の処理が未定義
- 推奨: '?' の場合は件数を0として扱うか、該当次元を失敗として扱うかを明記する
- impact: medium, effort: low

## 改善提案

### I-1: Phase 0 でエージェント定義内容を保持し続ける [efficiency]
- 対象: Phase 0 Step 2 の `{agent_content}` 保持処理
- 内容: Phase 0 Step 2 で `{agent_content}` として保持された内容は、Phase 0 Step 4 のグループ分類後は使用されない。Phase 1 の次元サブエージェントは `{agent_path}` を直接 Read するため、親コンテキストに全文を保持する必要はない
- 推奨: 分類完了後に破棄すべき
- impact: medium, effort: low

### I-2: Phase 0 グループ分類ロジックの重複 [architecture]
- 対象: SKILL.md:62-72
- 内容: グループ分類判定ロジックと group-classification.md の内容が重複している
- 推奨: group-classification.md を Read + apply で一貫性を保つべき
- impact: medium, effort: low

### I-3: 次元エージェントテンプレートのサイズ [architecture]
- 対象: agents/ 配下のテンプレート
- 内容: agents/ 配下のテンプレートが172-201行と大きい。Phase 1 並列実行時に各サブエージェントが全文を読み込むため、コンテキスト効率を考慮すると150行以下への削減を検討すべき
- 推奨: テンプレートサイズを150行以下に削減する
- impact: medium, effort: high

### I-4: 検証失敗時の処理継続 [ux]
- 対象: Phase 2 検証ステップ
- 内容: 検証失敗時にロールバック手順を表示するが、自動ロールバックは行わず Phase 3 に進む設計。検証失敗は適用処理の重大な異常（構造破壊・部分適用の可能性）を示すため、Phase 3 サマリを表示する前に「自動ロールバックを実行しますか？（実行 / スキップ）」をAskUserQuestionで確認し、ユーザーが承認した場合は `cp {backup_path} {agent_path}` を実行してからPhase 3に進む方が安全性が高い
- 推奨: 検証失敗時に自動ロールバック確認を追加する
- impact: medium, effort: low

### I-5: 冪等性: バックアップの重複生成 [stability]
- 対象: SKILL.md:234-236
- 内容: 既存バックアップがあれば再利用するロジックはあるが、Phase 2を複数回実行した場合、最初のバックアップが後続の適用後の状態を保存していない
- 推奨: 「バックアップは初回実行時のみ作成し、改善適用後は新規バックアップを作成しない」という方針を明記するか、「毎回タイムスタンプ付きバックアップを作成する」に変更する
- impact: medium, effort: low

### I-6: 欠落ステップ - 検証結果のユーザー報告が不完全 [effectiveness]
- 対象: Phase 2 Step 4 検証ステップ
- 内容: SKILL.md 264-265行で「検証成功時: 『✓ 検証完了: エージェント定義の構造は正常で、{N}件の改善が適用されています』とテキスト出力」と記載されているが、検証結果（改善前後の diff、各 finding の適用確認詳細）は親コンテキストに保持されるのみでファイル出力されない。Phase 3 完了サマリでは「変更詳細」として適用成功・スキップ件数のみが表示される。ユーザーが「実際に何が変更されたか」を事後確認する手段がバックアップとの diff 比較のみとなる
- 推奨: 検証結果を `.agent_audit/{agent_name}/verification.md` に保存し、Phase 3 で参照可能にする改善が推奨される
- impact: medium, effort: low

### I-7: 親が各次元の findings ファイルを Phase 2 Step 1 で全件 Read する [efficiency]
- 対象: Phase 2 Step 1 の findings 収集処理
- 内容: Phase 1 の返答バリデーションで既に件数を把握している。Phase 2 で全 findings を収集・ソート・表示するが、実際の承認時には個別 finding の詳細は AskUserQuestion の直前で必要なときに Read すれば十分。一括 Read は承認数が 0 の場合に無駄になる
- 推奨: 承認時に必要なときのみ個別 Read するように変更する
- impact: low, effort: medium

### I-8: Phase 1 返答バリデーション処理の長さ [architecture]
- 対象: SKILL.md:125-130
- 内容: バリデーション・エラーハンドリング・部分成功判定ロジックが15行を超える複雑な処理を含む
- 推奨: テンプレートに外部化して処理の可読性を向上すべき
- impact: low, effort: medium

### I-9: apply-improvements.md テンプレートの変更適用ルール詳細度 [architecture]
- 対象: templates/apply-improvements.md:20-27
- 内容: 変更適用ルールが8行にわたり、二重適用チェック・Edit優先・ユーザー修正優先など複数の処理方針を含む。サブエージェントプロンプトとしては適切だが、今後の拡張時に複雑化リスクがある
- 推奨: ルールを簡潔化またはより詳細なサブテンプレートに分割する
- impact: low, effort: medium
