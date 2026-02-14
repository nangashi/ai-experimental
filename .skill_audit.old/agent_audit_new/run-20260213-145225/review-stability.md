### 安定性レビュー結果

#### 重大な問題
- [参照整合性: SKILL.md Phase 2 Step 1 の previous_approved_count 変数が未定義]: [SKILL.md] [行201: dim_summaries から件数を取得と記載があるが、analysis.md によると実際は抽出結果から集計となっており、定義が矛盾] [resolved-issues.md の Phase 2 Step 1 件数集計で「dim_summaries から直接件数を取得」と記載されているが、SKILL.md L201 では「抽出結果から集計」と矛盾] → [Phase 2 Step 1 の L201「抽出した findings を severity 順（critical → improvement）にソートする」の後に「`{total}` = `{dim_summaries}` から全次元の critical + improvement 件数を合計」を追加し、dim_summaries の使用を明示する] [impact: medium] [effort: low]
- [条件分岐の完全性: Phase 1 共通フレームワーク要約の抽出方法が未定義]: [SKILL.md] [行142-146: analysis-framework.md から要約を抽出する処理が「以下の要約を抽出」と列挙のみで、抽出方法（全文コピー/要約生成/特定セクション抽出）が不明確] [「抽出」と記載されているが、具体的な処理（Read後の全文コピー、LLMによる要約、特定セクションの切り出し）が明示されていないため、LLMが異なる解釈で実行する可能性がある] → [L142-146 を「Read で analysis-framework.md を読み込み、以下の項目を含む要約テキストを生成する」または「以下のセクションをそのままコピーして各次元エージェントに渡す」のように処理を明示する] [impact: high] [effort: low]
- [出力フォーマット決定性: Phase 0 グループ分類サブエージェント返答の抽出失敗時の具体的エラー内容が不明]: [SKILL.md] [行88-91: 抽出失敗時の条件は列挙されているが、「形式不一致、不正な値、複数行存在」のどれが発生したかをユーザーに報告する処理が欠落] [抽出失敗時にデフォルト値を使用することは明示されているが、失敗理由が分からないとデバッグが困難。LLMが自然にエラー詳細を報告するかは不確定] → [L91 の警告表示を「⚠ グループ分類結果の抽出に失敗しました（{理由: 形式不一致/不正な値/複数行存在}）。デフォルト値 "unclassified" を使用します。」に変更し、失敗理由を含める処理を追加] [impact: medium] [effort: low]
- [冪等性: Phase 2 Step 3 の audit-approved.md 上書き時の重複データ問題]: [SKILL.md] [行240: Write で audit-approved.md を上書きすると、同じスキル実行の2回目以降で前回の承認結果が失われる] [run-YYYYMMDD-HHMMSS サブディレクトリは冪等性確保されているが、audit-approved.md は常に上書きされるため、履歴追跡が不可能。resolved-issues.md には「履歴管理のため最新版のみ保持」と記載されているが、前回比較（Phase 3 L327-332）には過去の findings ID が必要なため、上書きにより情報欠落が発生] → [audit-approved.md を {run_dir}/ 配下に保存し、最新版へのシンボリックリンクを .agent_audit/{agent_name}/audit-approved.md に作成する。または L106 の注釈を「前回比較のため最新版へのリンクを .agent_audit/{agent_name}/ に保持」に修正し、上書き前に Read した内容を {previous_approved_findings} 変数に保持してコンテキストで管理する方式に変更] [impact: high] [effort: medium]

#### 改善提案
- [指示の具体性: Phase 2 Step 2a の入力内容不明確判定基準が曖昧]: [SKILL.md] [行232: 「2行以下で具体性なし、文脈不明」という判定基準が主観的。LLMによって判定が変わる可能性] [具体的な例（「OK」「わかった」「変更して」のみ等）を提示するか、文字数・キーワード基準を追加すると安定性が向上] [impact: low] [effort: low]
- [出力フォーマット決定性: Phase 3 の前回比較における「解決済み指摘」の導出方法が未定義]: [SKILL.md] [行331: 「前回承認済みで今回検出されなかった finding ID」の比較方法（ID文字列照合/タイトル類似度/内容一致等）が明示されていない] [前回と今回の finding ID セットの差分を取る処理を明示する（例: 「前回 audit-approved.md の全 finding ID を抽出し、今回の全検出 finding ID（Phase 1 全次元）と照合」）] [impact: medium] [effort: low]
- [条件分岐の完全性: Phase 1 エラーハンドリングにおける findings ファイルの「空」判定基準が不明]: [SKILL.md] [行169: 「空でない」の定義が曖昧（0バイト/空行のみ/Summary セクションなし等）] [「ファイルサイズが0バイトでない」または「Summary セクションが存在する」等の具体的基準を明示] [impact: medium] [effort: low]
- [参照整合性: Phase 2 Step 3 のフォーマットで修正内容フィールドが常に表示される]: [SKILL.md] [行255: 「修正して承認」以外の場合でも「修正内容:」フィールドが表示される記述になっている] [L254-255 を「- **ユーザー判定**: 承認 / 修正して承認」「{修正して承認の場合のみ}- **修正内容**: {修正内容}」のように条件分岐を明確化] [impact: low] [effort: low]
- [指示の具体性: Phase 2 Step 2a の「残りすべて承認」における「残り」の範囲が不明確]: [SKILL.md] [行235: 「未確認の全指摘」とあるが、既に承認/スキップした指摘を含むかが読み取れない] [resolved-issues.md に「severity 関係なく全承認」と記載されているが、SKILL.md では「未確認の」と記載されており整合性が取れている。ただし「この指摘を含め、」の「この指摘」が現在確認中の指摘を指すことを明示すると、より明確になる] [impact: low] [effort: low]
- [出力フォーマット決定性: テンプレート apply-improvements.md の skipped リスト省略時の表記]: [templates/apply-improvements.md] [行39: 「... and {N} more」という省略表記が、modified/skipped の両方で使用されるが、上限超過時の N の計算方法（超過分の件数 or 残り全件数）が不明] [「超過分の件数」を明示（例: 「modified リストが上限20件を超えた場合、21件目以降を `... and {超過件数} more` で省略」）] [impact: low] [effort: low]
- [条件分岐の完全性: Phase 2 検証ステップにおける「必須セクション欠落」時の処理が不明確]: [SKILL.md] [行289-292: グループ別必須セクション検証で欠落検出後、どのセクション欠落がロールバック対象かの判定基準がない] [全必須セクションが存在する場合のみ検証成功とするか、部分的欠落を許容するかを明示（例: 「いずれか1つでも欠落した場合は検証失敗」）] [impact: medium] [effort: low]

#### 良い点
- [冪等性: Phase 0 Step 6 のタイムスタンプ付きサブディレクトリによる再実行安全性確保]: run-YYYYMMDD-HHMMSS 方式により、複数回実行時の findings ファイル上書き問題が解決されている
- [出力フォーマット決定性: Phase 1 サブエージェント返答の複数フォールバックによる堅牢性]: サブエージェント返答からの件数抽出失敗時に、findings ファイルの Summary セクションから再抽出する2段階フォールバックが定義されている
- [参照整合性: 全テンプレート・補助ファイルの実在確認済み]: SKILL.md で参照される全ファイル（group-classification.md, analysis-framework.md, agents/*/**.md, templates/apply-improvements.md）がスキルディレクトリ内に実在し、外部依存がない
