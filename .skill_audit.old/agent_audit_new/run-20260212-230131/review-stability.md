### 安定性レビュー結果

#### 重大な問題
- [参照整合性: 外部パス参照のスキル名不一致]: [SKILL.md] [行64, 221] [`.claude/skills/agent_audit/` への参照] → [`.claude/skills/agent_audit_new/` に修正する。現在のスキル名は `agent_audit_new` だが、SKILL.md 内で旧スキル名 `agent_audit` のパスを参照しており、実行時に Read 失敗が発生する] [impact: high] [effort: low]

- [冪等性: Phase 2 Step 4 の再実行でバックアップファイルが無限増殖]: [SKILL.md] [行217] [`cp {agent_path} {agent_path}.backup-$(date +%Y%m%d-%H%M%S)` が無条件実行] → [バックアップ作成前に既存バックアップの存在確認を追加。既存バックアップがある場合は再利用または別名生成ルールを明示する] [impact: medium] [effort: low]

- [条件分岐の完全性: Phase 0 Step 3 の YAML 検証失敗後の処理が未定義]: [SKILL.md] [行58] [「警告を出力する（処理は継続する）」とあるが、継続時にフォールバック処理（frontmatter 生成または検証スキップ）が明示されていない] → [frontmatter 不在時の処理を明示（例: 「ユーザーに継続可否を確認する」または「frontmatter なしで分析を継続する」）] [impact: high] [effort: low]

- [出力フォーマット決定性: Phase 1 サブエージェント返答の行数が明示されているが、区切り文字が未定義]: [SKILL.md] [行118] [返答フォーマット `dim: {次元名}, critical: {N}, improvement: {M}, info: {K}` で区切り文字がカンマとスペースだが、次元名にカンマが含まれる場合のエスケープルールがない] → [次元名を引用符で囲む（例: `dim: "IC", critical: 2`）またはカンマを別の区切り文字（タブ、セミコロン等）に変更する] [impact: medium] [effort: low]

- [参照整合性: テンプレート内のプレースホルダ `{agent_content}` が SKILL.md のパス変数リストで未定義]: [SKILL.md] [パス変数リスト不在、行57で `{agent_content}` 使用] [SKILL.md には「パス変数」リストが存在せず、テンプレートに渡すべき変数が暗黙的。`{agent_content}`, `{agent_group}`, `{agent_name}`, `{dim_count}`, `{dim_path}`, `{ID_PREFIX}`, `{findings_save_path}` 等が定義されていない] → [SKILL.md 冒頭に「## パス変数」セクションを追加し、全プレースホルダと導出ルールを明記する。または Phase 0-2 の各ステップで使用する変数をステップ内で明示する] [impact: high] [effort: medium]

#### 改善提案
- [指示の具体性: グループ判定の「主たる機能」が曖昧]: [SKILL.md] [行62] [「主たる機能に注目して分類する」が抽象的。複数機能が混在する場合の優先順位が不明確] → [「主たる機能 = frontmatter の description または最初の見出しで言及された目的」と具体化する。または「特徴数が同数の場合は hybrid > evaluator > producer の順で分類」と優先順位を明示する] [impact: medium] [effort: low]

- [出力フォーマット決定性: Phase 2 Step 2a の AskUserQuestion 選択肢が「Other」を含む記述と4選択肢の不一致]: [SKILL.md] [行181] [「選択肢は以下の4つ。ユーザーが "Other" で修正内容をテキスト入力した場合は...」とあるが、4選択肢に「Other」が含まれていない。AskUserQuestion の選択肢形式が未定義] → [選択肢リストに「Other: 修正内容を入力」を5番目として明記する。または「4選択肢 + ユーザーがテキスト入力した場合は修正として扱う」と修正する] [impact: medium] [effort: low]

- [冪等性: Phase 1 の findings ファイルが既存の場合の処理が未定義]: [SKILL.md] [行111-122] [サブエージェントが Write で findings を保存するが、既存ファイルの上書き/追記ルールが不明。再実行時に古い findings が残るリスク] → [サブエージェント起動前に既存 findings ファイルを削除（Bash で `rm -f .agent_audit/{agent_name}/audit-*.md`）するか、サブエージェントに「Write は上書き」と明示する] [impact: medium] [effort: low]

- [参照整合性: サブエージェント定義内の `{agent_path}` 等の変数が親スキルで展開されるか不明]: [agents/shared/instruction-clarity.md] [行12] [「Read `{agent_path}` (provided as input parameter by the parent skill)」とあるが、SKILL.md の Task prompt（行115-118）で変数展開ルールが不明確。テンプレートに渡す際に `{agent_path}` をそのまま渡すのか、実際のパスに置換するのか未定義] → [SKILL.md の Phase 1 Task prompt に「以下の変数を実際の値に置換して指示を生成する: agent_path={実際のパス}, agent_name={実際の名前}」と明記する] [impact: high] [effort: low]

- [条件分岐の完全性: Phase 1 エラーハンドリングで「全て失敗した場合」の定義が曖昧]: [SKILL.md] [行129] [「全て失敗した場合: エラー出力して終了」とあるが、「全て」の定義が不明（全次元が起動失敗? 全 findings ファイルが空?）] → [「全次元の findings ファイルが存在しないまたは空の場合」と具体化する] [impact: low] [effort: low]

- [出力フォーマット決定性: Phase 2 Step 3 の audit-approved.md フォーマットで「修正内容」の記述位置が重複]: [SKILL.md] [行202-204] [「ユーザー判定: 承認 / 修正して承認」「修正内容: {修正して承認の場合のみ記載}」とあるが、「承認」の場合は修正内容フィールド自体を出力しないのか、空で出力するのか不明] → [「承認の場合は修正内容フィールドを省略する」または「修正内容: なし」と明示する] [impact: low] [effort: low]

- [指示の具体性: Phase 2 検証ステップの「構造は正常」の定義が不完全]: [SKILL.md] [行232-234] [YAML frontmatter の存在確認のみで「正常」と判定しているが、frontmatter 内の必須フィールド（description 等）の検証が不足] → [「frontmatter が存在し、description フィールドが空でない場合に正常と判定」と具体化する] [impact: low] [effort: low]

#### 良い点
- [冪等性: Phase 2 Step 4 のバックアップ作成により、改善適用失敗時のロールバックが可能]
- [条件分岐の完全性: Phase 1 でサブエージェント失敗を検出し、部分完了でも処理を継続する設計]
- [出力フォーマット決定性: サブエージェント返答が厳密な4行フォーマットで定義され、解析が容易]
