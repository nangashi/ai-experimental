# 承認済みフィードバック

承認: 18/18件（スキップ: 0件）

## 重大な問題

### C-1: 外部パス参照のスキル名不一致 [architecture, efficiency, effectiveness, stability]
- 対象: SKILL.md:64, 221
- 内容: `.claude/skills/agent_audit/` への参照が残存し、実際のスキルディレクトリ `agent_audit_new/` と不一致。Phase 0 Step 4 のグループ分類基準ファイル参照と Phase 2 Step 4 のテンプレートファイル参照が実行時にファイル不在エラーを起こす
- 推奨: 全パス参照を `.claude/skills/agent_audit_new/` に修正する。具体的には (1) 64行目: group-classification.md のパス修正、(2) 221行目: apply-improvements.md のパス修正、(3) 115-118行目: Phase 1 サブエージェント指示内の各次元エージェント定義ファイルのパス修正
- **ユーザー判定**: 承認

### C-2: パス変数定義の欠落 [stability]
- 対象: SKILL.md:全体
- 内容: テンプレートやサブエージェント指示内で使用される変数（`{agent_content}`, `{agent_group}`, `{agent_name}`, `{dim_count}`, `{dim_path}`, `{ID_PREFIX}`, `{findings_save_path}` 等）が SKILL.md 冒頭で定義されていない。変数の導出ルールが暗黙的であり、テンプレート開発者が参照できるドキュメントがない
- 推奨: SKILL.md 冒頭に「## パス変数」セクションを追加し、全プレースホルダと導出ルールを明記する。例: `{agent_name}` = `.claude/` 配下の場合は `.claude/` からの相対パス（拡張子除去）、それ以外はプロジェクトルートからの相対パス（拡張子除去）
- **ユーザー判定**: 承認

### C-3: Phase 0 Step 3 YAML 検証失敗後の処理未定義 [stability]
- 対象: SKILL.md:58
- 内容: frontmatter が存在しない場合に「警告を出力する（処理は継続する）」とあるが、継続時のフォールバック処理（frontmatter 生成または検証スキップ）が明示されていない。処理継続時に後続ステップで frontmatter を前提とする処理が失敗する可能性がある
- 推奨: frontmatter 不在時の処理を明示する。例: 「ユーザーに継続可否を AskUserQuestion で確認し、継続する場合は frontmatter なしで分析を継続する（検証ステップをスキップ）」と記述する
- **ユーザー判定**: 承認

### C-4: サブエージェント変数展開ルールの曖昧性 [stability]
- 対象: SKILL.md:115-118, agents/shared/instruction-clarity.md:12
- 内容: Phase 1 のサブエージェント Task prompt 内で `{agent_path}`, `{agent_name}` 等の変数を使用しているが、親スキルがこれらを実際の値に置換して渡すのか、変数名のまま渡すのかが不明確。サブエージェントテンプレート内では「(provided as input parameter by the parent skill)」とあるが、SKILL.md に明示的な展開ルールがない
- 推奨: SKILL.md の Phase 1 Task prompt に「以下の変数を実際の値に置換して指示を生成する: agent_path={実際のパス}, agent_name={実際の名前}, dim_path={次元の相対パス}, ID_PREFIX={次元のプレフィックス}, findings_save_path={保存先パス}」と明記する
- **ユーザー判定**: 承認

### C-5: エラー通知の動的情報不足 [ux]
- 対象: Phase 1
- 内容: findings ファイルが存在しない場合に「分析失敗（{エラー概要}）」と表示されるが、エラー概要の抽出方法が不明確で、具体的な失敗理由（ファイル読み込みエラー、解析エラー等）やリトライ手順が示されない
- 推奨: サブエージェント失敗時に TaskOutput または標準エラー出力を取得し、エラー概要に含める。また、「リトライ方法: `/agent_audit {agent_path}` を再実行してください」と明示する
- **ユーザー判定**: 承認

### C-6: Phase 2 Step 4 サブエージェント失敗時のフォールバック未定義 [architecture, effectiveness]
- 対象: SKILL.md:219-226
- 内容: apply-improvements.md サブエージェントの Task 実行失敗時、リトライ・ロールバック・中止の分岐処理が記述されていない。改善適用が部分的に失敗した場合の状態が不明確になる
- 推奨: Phase 2 Step 4 に失敗時の処理フローを追加する。例: 「失敗時: (1) バックアップからロールバックコマンドを表示、(2) ユーザーに手動修正を促す、(3) 失敗理由を出力（TaskOutput から抽出）」
- **ユーザー判定**: 承認

### C-7: ユーザー確認の欠落 [ux]
- 対象: Phase 2 Step 3
- 内容: 承認結果を audit-approved.md に保存する前に、保存内容のプレビューや最終確認が行われない。ユーザーは承認内容を確認する機会がない
- 推奨: Phase 2 Step 3 の Write 前に、保存内容を出力し「以上の内容を {audit-approved.md パス} に保存します。よろしいですか？」と AskUserQuestion で確認する
- **ユーザー判定**: 承認

### C-8: agent_content の二重保持 [efficiency]
- 対象: SKILL.md:Phase 0 + Phase 2
- 内容: Phase 0 で `{agent_content}` としてエージェント定義全文を保持し、Phase 2 検証ステップで再度 Read する。親コンテキストに全文保持は不要で、必要時に Read で取得すべき
- 推奨: Phase 0 では `{agent_content}` を保持せず、Phase 2 検証ステップで初めて Read する
- **ユーザー判定**: 承認

### C-9: Phase 2 Step 4 バックアップファイルの無限増殖 [stability]
- 対象: SKILL.md:217
- 内容: `cp {agent_path} {agent_path}.backup-$(date +%Y%m%d-%H%M%S)` が無条件実行されるため、再実行のたびにバックアップファイルが増殖する
- 推奨: バックアップ作成前に既存バックアップの存在確認を追加。既存バックアップがある場合は再利用または「最新バックアップは {パス} です。新しいバックアップを作成しますか？」と確認する
- **ユーザー判定**: 承認

## 改善提案

### I-1: 一括承認パターンの粒度不足 [ux]
- 対象: Phase 2 Step 2
- 内容: 承認方針として「全て承認」「1件ずつ確認」「キャンセル」の3択を提示しているが、「全て承認」を選択すると全 findings を一括承認してしまう。critical と improvement が混在する場合、ユーザーは重大な問題のみを先に確認したい可能性がある
- 推奨: severity ごとの承認（「critical のみ承認」「improvement のみ承認」）を追加するか、デフォルトを「1件ずつ確認」にする
- **ユーザー判定**: 承認

### I-2: ユーザー入力内容のプレビュー不足 [ux]
- 対象: Phase 2 Step 2a
- 内容: ユーザーが "Other" で修正内容を入力した場合、「修正して承認」として扱われるが、入力内容がそのまま改善計画に反映される前に確認画面がない
- 推奨: 入力内容のプレビューを表示し、「この内容で適用しますか？ {入力内容}」と確認する
- **ユーザー判定**: 承認

### I-3: 検証失敗時のメッセージ具体性不足 [ux]
- 対象: Phase 2 検証ステップ
- 内容: 「エージェント定義が破損している可能性があります」と表示されるが、具体的にどの部分が破損しているか（frontmatter がない、description フィールドがない等）が示されない
- 推奨: 失敗内容を具体的に表示する。例: 「検証失敗: frontmatter が見つかりません」「検証失敗: description フィールドが空です」
- **ユーザー判定**: 承認

### I-4: SKILL.md 行数超過 [architecture]
- 対象: SKILL.md
- 内容: 279行で品質基準（250行以下）を超過。Phase 0 Step 4 のグループ分類判定ルール（66-72行）は group-classification.md へ委譲すべき
- 推奨: Phase 0 Step 4 の判定ルールを group-classification.md に移動し、SKILL.md では「Read group-classification.md and follow instructions」のみ記述する
- **ユーザー判定**: 承認

### I-5: findings 収集時のコンテキスト肥大化リスク [architecture]
- 対象: SKILL.md:Phase 2 Step 1
- 内容: critical + improvement findings を全て親コンテキストに保持する設計。findings 件数が多い場合（>50件）コンテキストが肥大化する
- 推奨: findings 要約のみを保持し、詳細はファイル参照にする。または Phase 1 サブエージェント返答を拡張し、メタデータ（ID, title, severity）を直接返答させる
- **ユーザー判定**: 承認

### I-6: Phase 2 Step 4 改善適用失敗時のリトライ判定基準不足 [effectiveness]
- 対象: Phase 2 Step 4
- 内容: 改善適用サブエージェントの失敗時に「返答内容を出力する」のみで、リトライ・ロールバック・中止の判定基準が記述されていない
- 推奨: 失敗時の対処フローを明確化する。例: 「失敗内容が Edit の old_string 不一致の場合はスキップ、ファイル読み込みエラーの場合はリトライ、構文エラーの場合は中止」
- **ユーザー判定**: 承認

### I-7: 検証ステップの構造検証スコープ不足 [architecture]
- 対象: SKILL.md:228-236
- 内容: 検証ステップは YAML frontmatter の存在のみ確認するが、必須フィールド（description, allowed-tools 等）の検証は未実装
- 推奨: 必須フィールドの存在確認を追加する。例: 「frontmatter が存在し、description フィールドが空でない場合に正常と判定」
- **ユーザー判定**: 承認

### I-8: グループ判定基準の曖昧性 [stability]
- 対象: SKILL.md:62
- 内容: 「主たる機能に注目して分類する」が抽象的。複数機能が混在する場合の優先順位が不明確
- 推奨: 「主たる機能 = frontmatter の description または最初の見出しで言及された目的」と具体化する。または「特徴数が同数の場合は hybrid > evaluator > producer の順で分類」と優先順位を明示する
- **ユーザー判定**: 承認

### I-9: サブエージェント返答フォーマットの区切り文字曖昧性 [stability]
- 対象: SKILL.md:118
- 内容: 返答フォーマット `dim: {次元名}, critical: {N}, improvement: {M}, info: {K}` で区切り文字がカンマとスペースだが、次元名にカンマが含まれる場合のエスケープルールがない
- 推奨: 次元名を引用符で囲む（例: `dim: "IC", critical: 2`）またはカンマを別の区切り文字（タブ、セミコロン等）に変更する
- **ユーザー判定**: 承認
