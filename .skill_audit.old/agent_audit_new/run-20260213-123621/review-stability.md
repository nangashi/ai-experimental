### 安定性レビュー結果

#### 重大な問題
- [参照整合性: テンプレート内の未定義プレースホルダ]: [templates/apply-improvements.md] [行22] [{agent_path} プレースホルダは、SKILL.md のパス変数リストで定義されているが、手順1で Read によって読み込まれた内容を指しているのか、ファイルパス文字列を指しているのかが不明瞭。保持した内容を使用する指示と、変数名が衝突している] → [プレースホルダ名を {agent_content} に変更し、SKILL.md のパス変数リストに {agent_content} を追加する。または、テンプレート内の記述を「手順1で Read した {agent_path} の内容を保持し」に明確化する] [impact: medium] [effort: low]

- [条件分岐の完全性: Phase 0 Step 3 の簡易チェック失敗時の処理]: [SKILL.md] [行69] [frontmatter が存在しない場合、警告を出力するが「処理は継続する」と明記。しかし、その後のグループ分類処理では frontmatter の description フィールドを参照する前提がない。エージェント定義でない場合のグループ分類の動作が未定義] → [Step 3 で frontmatter が存在しない場合の処理を明示する: (1) グループ分類処理をスキップして unclassified とする、(2) AskUserQuestion で継続/中止を確認する、のいずれかを採用し、以降のフローに明示的な分岐を追加する] [impact: high] [effort: medium]

- [条件分岐の完全性: Phase 1 で全次元失敗時の処理]: [SKILL.md] [行152] [全次元失敗時にエラー出力して終了するが、Phase 2 へのスキップ処理や、Phase 3 での失敗サマリ出力との整合性が不明確。全失敗は完了サマリを出力せずに終了するのか、Phase 3 で失敗状況を報告するのかが未定義] → [全次元失敗時の処理を明示する: 「エラー出力して終了する（Phase 3 はスキップ）」または「Phase 3 へ進み、全失敗サマリを出力する」のいずれかを選択し、フローに明記する] [impact: high] [effort: medium]

- [冪等性: Phase 2 Step 3 の承認結果ファイル書き込み]: [SKILL.md] [行213] [`.agent_audit/{agent_name}/audit-approved.md` に Write で保存するが、再実行時の既存ファイル確認や上書き警告がない。前回の承認結果が上書きされる] → [Step 3 の前に Read で既存の audit-approved.md を確認し、存在する場合は AskUserQuestion で上書き確認を行うか、タイムスタンプ付きファイル名 (`audit-approved-{timestamp}.md`) に変更する] [impact: medium] [effort: medium]

- [冪等性: Phase 2 Step 4 のバックアップ作成]: [SKILL.md] [行239] [バックアップファイル名に `$(date +%Y%m%d-%H%M%S)` を使用しているが、同一分内に複数回実行すると同じバックアップファイル名になり上書きされる可能性がある。また、バックアップファイルの累積管理（古いバックアップの削除）についての記述がない] → [バックアップファイル名にミリ秒を含めるか、ファイル存在確認を行い既存の場合は `-2`, `-3` のような連番を付与する。また、バックアップの保持期間や削除方針を SKILL.md に記述する] [impact: medium] [effort: low]

#### 改善提案
- [出力フォーマット決定性: Phase 0 グループ判定根拠の出力フォーマット]: [SKILL.md] [行122] [検出された特徴を「カンマ区切り」で出力する指示があるが、各特徴を具体的にどのテキストで表現するかが不明確。evaluator 特徴4項目、producer 特徴4項目の具体的なラベル表現が定義されていない] → [グループ分類基準ファイル (group-classification.md) に、各特徴の出力ラベル（例: "評価基準定義", "findings出力構造", "severity分類", "スコープ定義" 等）を明示し、Phase 0 でこのラベルを使用するよう指示する] [impact: low] [effort: low]

- [指示の具体性: Phase 1 のサブエージェント Task prompt 内の変数展開]: [SKILL.md] [行137-140] [Task prompt 内で `{agent_path}`, `{agent_name}`, `{findings_save_path}`, `{ID_PREFIX}` を使用しているが、これらが「波括弧付きプレースホルダとして渡す」のか「実際の値に展開してから渡す」のかが不明確] → [「以下のテンプレートプロンプトの波括弧プレースホルダを実際の値に置換してから Task に渡す」と明記する。または、apply-improvements.md のように「パス変数（波括弧付きプレースホルダとして渡す）」と明示する] [impact: medium] [effort: low]

- [条件分岐の完全性: Phase 2 Step 2a の「残りすべて承認」再確認での「いいえ」分岐]: [SKILL.md] [行206] [「いいえ」選択時に「次の指摘へ戻る」とあるが、この「次の指摘」が「残りすべて承認」を選択した時点の指摘なのか、その次の未確認指摘なのかが曖昧] → [「いいえ」選択時の動作を明確化: 「現在の指摘に対して再度4択の方針確認を行う（ループ継続）」と記述する] [impact: medium] [effort: low]

- [参照整合性: テンプレートファイルパス参照の検証不足]: [SKILL.md] [行137-138, 243] [テンプレートファイルパスを `.claude/skills/agent_audit_new/agents/{dim_path}.md` および `.claude/skills/agent_audit_new/templates/apply-improvements.md` として記述しているが、これらのパスが実在するかの検証ステップが Phase 0 に含まれていない] → [Phase 0 の初期化ステップに、dimensions テーブルで使用する全テンプレートファイルの実在確認（Glob または Read による存在チェック）を追加し、不在時はエラー出力して終了する処理を記述する] [impact: medium] [effort: medium]

- [冪等性: Phase 0 Step 6 の出力ディレクトリ作成]: [SKILL.md] [行102] [`mkdir -p .agent_audit/{agent_name}/` を実行するが、ディレクトリが既存の場合の挙動（既存 findings ファイルの上書き可能性）について記述がない] → [既存ディレクトリの場合、既存の findings ファイル一覧を Glob で確認し、上書き警告を出力するか、タイムスタンプ付きサブディレクトリを作成する方針を記述する] [impact: low] [effort: medium]

- [出力フォーマット決定性: Phase 3 の失敗次元の表示フォーマット]: [SKILL.md] [行292] [失敗次元の ID 列挙と「エラー概要」を表示するが、複数次元が失敗した場合の表示フォーマット（各次元の ID とエラー概要の対応関係）が不明確] → [失敗次元の表示フォーマットを明示: 「失敗次元: {ID1}（{エラー概要1}）, {ID2}（{エラー概要2}）」のようにカンマ区切りで各次元のエラー情報を記述する] [impact: low] [effort: low]

- [指示の具体性: Phase 2 Step 1 の「findings 内容を変数に保持する」]: [SKILL.md] [行171] [「以降は保持した内容を使用する」とあるが、どの変数名で保持するか、どのフォーマットで保持するかが不明確] → [保持する変数名とフォーマットを明示: 「各次元の findings を {dim_id}_findings 変数に文字列として保持し、以降の Step で再度 Read せずにこの変数を使用する」] [impact: low] [effort: low]

#### 良い点
- [出力フォーマット決定性]: サブエージェントからの返答フォーマットが厳密に定義されている（Phase 1: 4行フォーマット、Phase 2 Step 4: 2行フォーマット）。行数・フィールド名・区切りが明示されており、パース可能性が高い
- [冪等性]: Phase 2 Step 4 でバックアップを作成してから改善適用を行い、検証ステップで frontmatter 破損を検出する設計により、データ損失リスクが低減されている
- [参照整合性]: テンプレート内のプレースホルダ（{agent_path}, {agent_name}, {findings_save_path}, {approved_findings_path}, {backup_path}）が SKILL.md のパス変数セクションで全て定義されている
