# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | templates/classify-agent-group.md | 新規作成 | Phase 0 グループ分類ロジックの外部化 | I-1 |
| 2 | templates/per-item-approval.md | 新規作成 | Phase 2 Step 2a 承認ループロジックの外部化 | I-2 |
| 3 | SKILL.md | 修正 | frontmatter検証失敗時の処理フロー追加 | C-1 |
| 4 | SKILL.md | 修正 | Phase 1 全次元失敗時の処理フロー明確化 | C-2 |
| 5 | SKILL.md | 修正 | グループ分類ロジックをテンプレート参照に置換 | I-1 |
| 6 | SKILL.md | 修正 | 承認ループロジックをテンプレート参照に置換 | I-2 |
| 7 | SKILL.md | 修正 | audit-approved.md上書き確認処理を追加 | C-4 |
| 8 | SKILL.md | 修正 | バックアップファイル名にミリ秒を追加 | C-5 |
| 9 | SKILL.md | 修正 | Phase 0 で agent_content の保持範囲を明示 | I-4 |
| 10 | templates/apply-improvements.md | 修正 | {agent_path}プレースホルダを{agent_content}に変更 | C-3 |
| 11 | templates/apply-improvements.md | 修正 | 二重適用チェック時の変更内容反映ステップ追加 | I-3 |
| 12 | SKILL.md | 修正 | パス変数リストに{agent_content}を追加 | C-3 |

## 各ファイルの変更詳細

### 1. templates/classify-agent-group.md（新規作成）
**対応フィードバック**: I-1: Phase 0 グループ分類ロジックの外部化

**変更内容**:
SKILL.md 73-92行目のインラインロジックを外部テンプレートに移動する。

**新規ファイル内容構成**:
- 手順1: {agent_content} を分析対象として受け取る
- 手順2: evaluator特徴（4項目）のチェック
- 手順3: producer特徴（4項目）のチェック
- 手順4: 判定ルールに従いグループを決定
- 返答フォーマット: `group: {agent_group}\nevaluator_features: {N}\nproducer_features: {M}\nevaluator_matched: {カンマ区切り}\nproducer_matched: {カンマ区切り}`

### 2. templates/per-item-approval.md（新規作成）
**対応フィードバック**: I-2: Phase 2 Step 2a 承認ループのテンプレート外部化

**変更内容**:
SKILL.md 190-207行目のインラインブロックを外部テンプレートに移動する。

**新規ファイル内容構成**:
- パス変数: {findings_list}, {total}
- 手順1: 各 finding を {N}/{total} のフォーマットでテキスト出力
- 手順2: AskUserQuestion で方針確認（承認/スキップ/残りすべて承認/キャンセル）
- 手順3: 「残りすべて承認」選択時の再確認処理
- 返答フォーマット: `approved: {IDリスト}\nskipped: {IDリスト}\ncancelled: true/false`

### 3. SKILL.md（修正）- C-1対応
**対応フィードバック**: C-1: Phase 0 frontmatter検証失敗時の処理フロー不足

**変更内容**:
- 69行目の後に処理フロー分岐を追加: frontmatter が存在しない場合の処理を明示
  - 現在: `（処理は継続する）` とのみ記述
  - 改善後: `（処理は継続する）。ただし、グループ分類では unclassified として扱う。以降の Step 4 ではグループ分類をスキップし、{agent_group} = "unclassified" とする`
- 73行目（グループ分類開始）の前に条件分岐を追加: `4. frontmatter検証が成功した場合のみ、以下のグループ分類を実行する（失敗した場合は {agent_group} = "unclassified" とし、Step 5 へ進む）:`

### 4. SKILL.md（修正）- C-2対応
**対応フィードバック**: C-2: Phase 1 全次元失敗時の処理フロー不明確

**変更内容**:
- 152行目: `「Phase 1: 全次元の分析に失敗しました。」とエラー出力して終了する。` → `「Phase 1: 全次元の分析に失敗しました。」とエラー出力し、Phase 3 へスキップする（Phase 2 は実行しない）。Phase 3 では全失敗のサマリを出力する`
- Phase 3（270行目以降）に全次元失敗時の分岐を追加:
  ```markdown
  Phase 1 が全次元失敗した場合:
  ```
  ## agent_audit 失敗
  - エージェント: {agent_name}
  - ファイル: {agent_path}
  - グループ: {agent_group}
  - 分析次元: {dim_count}件
  - 結果: 全次元の分析に失敗しました
  - 失敗次元: {各次元のエラー概要を列挙}
  ```
  ```

### 5. SKILL.md（修正）- I-1対応
**対応フィードバック**: I-1: Phase 0 グループ分類ロジックの外部化

**変更内容**:
- 73-92行目の分類ロジック → テンプレート参照に置換:
  - 削除範囲: 73-92行目（evaluator特徴/producer特徴/判定ルールのインライン記述）
  - 追加内容（73行目に挿入）:
    ```markdown
    4. Task ツールで以下を実行する（subagent_type: "general-purpose", model: "sonnet"）:

    > `.claude/skills/agent_audit_new/templates/classify-agent-group.md` を Read で読み込み、その指示に従ってグループ分類を実行してください。
    > 分析対象内容: {agent_content}（変数に保持されている内容を渡す）
    > 分析完了後、以下のフォーマットで必ず返答してください: group: {agent_group}\nevaluator_features: {N}\nproducer_features: {M}\nevaluator_matched: {カンマ区切り}\nproducer_matched: {カンマ区切り}

    サブエージェント完了後、返答から {agent_group}, evaluator特徴数, producer特徴数, 検出特徴リストを抽出し、変数に保持する。
    ```
- パス変数リスト（20-29行目）に追加: `- {classify_template_path}: グループ分類テンプレートのパス（.claude/skills/agent_audit_new/templates/classify-agent-group.md の絶対パス）`

### 6. SKILL.md（修正）- I-2対応
**対応フィードバック**: I-2: Phase 2 Step 2a 承認ループのテンプレート外部化

**変更内容**:
- 190-207行目の承認ループロジック → テンプレート参照に置換:
  - 削除範囲: 190-207行目（per-item承認の詳細手順）
  - 追加内容（190行目に挿入）:
    ```markdown
    #### Step 2a: Per-item 承認（「1件ずつ確認」選択時のみ）

    Task ツールで以下を実行する（subagent_type: "general-purpose", model: "sonnet"）:

    > `.claude/skills/agent_audit_new/templates/per-item-approval.md` を Read で読み込み、その指示に従って承認処理を実行してください。
    > findings リスト: {保持した findings リストの内容を渡す}
    > 総件数: {total}
    > 分析完了後、以下のフォーマットで必ず返答してください: approved: {IDリスト}\nskipped: {IDリスト}\ncancelled: true/false

    サブエージェント完了後、返答から承認IDリスト、スキップIDリスト、キャンセルフラグを抽出し、変数に保持する。cancelled = true の場合、Phase 3 へ直行する。
    ```
- パス変数リスト（20-29行目）に追加: `- {approval_template_path}: 承認ループテンプレートのパス（.claude/skills/agent_audit_new/templates/per-item-approval.md の絶対パス）`

### 7. SKILL.md（修正）- C-4対応
**対応フィードバック**: C-4: Phase 2 承認結果ファイルの上書きリスク

**変更内容**:
- Step 3（209行目以降）の冒頭に上書き確認処理を追加:
  - 挿入位置: 209行目（Step 3見出しの直後）
  - 追加内容:
    ```markdown
    既存の承認結果ファイル（`.agent_audit/{agent_name}/audit-approved.md`）が存在する場合、Read で確認し、AskUserQuestion で上書き確認を行う:
    - 選択肢: 「上書き」/ 「キャンセル」
    - 「キャンセル」選択時: Phase 3 へ直行する（改善適用なし）
    - 「上書き」選択時: 以下の保存処理を続行する

    ```

### 8. SKILL.md（修正）- C-5対応
**対応フィードバック**: C-5: バックアップファイル名の重複可能性

**変更内容**:
- 239行目: `cp {agent_path} {agent_path}.backup-$(date +%Y%m%d-%H%M%S)` → `cp {agent_path} {agent_path}.backup-$(date +%Y%m%d-%H%M%S-%N | cut -c1-12)`
  - 理由: `-N`（ナノ秒）を追加し、先頭12文字（ミリ秒相当）を使用することで同一分内の重複を回避

### 9. SKILL.md（修正）- I-4対応
**対応フィードバック**: I-4: agent_content の Phase 2 での再利用が暗黙的

**変更内容**:
- Phase 0 Step 2（68行目）の記述を明確化:
  - 現在: `Read で `agent_path` のファイルを読み込み、`{agent_content}` として保持する。読み込み失敗時はエラー出力して終了`
  - 改善後: `Read で `agent_path` のファイルを読み込み、`{agent_content}` として保持する（この変数は Phase 2 検証ステップまで保持される）。読み込み失敗時はエラー出力して終了`

### 10. templates/apply-improvements.md（修正）- C-3対応
**対応フィードバック**: C-3: テンプレート内の未定義プレースホルダ

**変更内容**:
- 全プレースホルダの名称変更: `{agent_path}` → `{agent_content}`（手順1, 21行目の参照箇所）
  - 4行目: `- {agent_path} （エージェント定義 — 変更対象）` → `- {agent_content} （エージェント定義の内容 — Phase 0 Step 2 で Read して保持されたもの）`
  - 21行目: `手順1で Read した {agent_path} の内容を保持し` → `手順1で保持した {agent_content} を使用し`
- ただし、パス変数として受け取る側（SKILL.md 244-246行目）は変更不要: 親が渡す変数名は agent_path のままとし、テンプレート内で agent_content として扱う（親側の変数名とテンプレート内の変数名が異なることを許容）

**補足**: C-3の推奨では「SKILL.md のパス変数リストに {agent_content} を追加する」とあるため、#12でパス変数リスト更新を実施

### 11. templates/apply-improvements.md（修正）- I-3対応
**対応フィードバック**: I-3: apply-improvements 二重適用チェック実装の補強

**変更内容**:
- 手順3（12行目以降）に変更内容反映ステップを追加:
  - 挿入位置: 手順3の各 finding 適用ループ内（現在の記述「各 finding の「推奨」に従い変更を行う」の後）
  - 追加内容:
    ```markdown
    - 各 finding の適用後、変更箇所の現在の内容を保持変数 {agent_content} に反映する（Edit で変更した箇所の old_string を new_string に置換）
    - 次の finding の適用時の二重適用チェックでは、この更新後の {agent_content} を使用する
    ```

### 12. SKILL.md（修正）- C-3対応（パス変数追加）
**対応フィードバック**: C-3: テンプレート内の未定義プレースホルダ

**変更内容**:
- パス変数リスト（20-29行目）に追加:
  - 挿入位置: 24行目（{agent_path} の次の行）
  - 追加内容: `- {agent_content}: エージェント定義ファイルの内容（Phase 0 Step 2 で Read して保持、Phase 2 検証ステップまで使用）`

## 新規作成ファイル
| ファイル | 目的 | 対応フィードバック |
|---------|------|------------------|
| templates/classify-agent-group.md | Phase 0 グループ分類ロジックのテンプレート外部化 | I-1 |
| templates/per-item-approval.md | Phase 2 Step 2a 承認ループロジックのテンプレート外部化 | I-2 |

## 削除推奨ファイル
（なし）

## 実装順序
1. **templates/classify-agent-group.md の新規作成**（変更#1）
   - 理由: SKILL.md の変更#5 でこのテンプレートを参照するため、先に作成が必要
2. **templates/per-item-approval.md の新規作成**（変更#2）
   - 理由: SKILL.md の変更#6 でこのテンプレートを参照するため、先に作成が必要
3. **templates/apply-improvements.md の修正**（変更#10, #11）
   - 理由: SKILL.md の変更#12 でパス変数リストに {agent_content} を追加する前に、テンプレート側のプレースホルダ名を変更しておく必要がある
4. **SKILL.md の修正**（変更#3, #4, #5, #6, #7, #8, #9, #12）
   - 理由: テンプレートファイルが全て準備された後に、SKILL.md でテンプレート参照・パス変数追加・フロー修正を一括実施
   - 変更の適用順序（同一ファイル内）:
     - #12 (24行目 - パス変数追加)
     - #9 (68行目 - agent_content保持範囲明示)
     - #3 (69行目 - frontmatter検証フロー追加)
     - #5 (73-92行目 - グループ分類テンプレート化)
     - #4 (152行目 + Phase 3 - 全次元失敗フロー明確化)
     - #6 (190-207行目 - 承認ループテンプレート化)
     - #7 (209行目 - audit-approved.md上書き確認)
     - #8 (239行目 - バックアップファイル名修正)

依存関係の検出方法:
- テンプレート新規作成（#1, #2）→ SKILL.md でのテンプレート参照追加（#5, #6）→ テンプレート作成が先
- テンプレートのプレースホルダ変更（#10）→ SKILL.md のパス変数リスト追加（#12）→ プレースホルダ変更が先

## 注意事項
- 変更#5, #6でテンプレート外部化を行う際、SKILL.md の既存記述を削除するため、削除範囲の行番号に注意する（他の変更の行番号がずれる可能性がある）
- テンプレート外部化により、Phase 0 と Phase 2 でサブエージェントが2つ増加する（合計: Phase 0 で1個、Phase 1 で3-5個、Phase 2 で2個）
- バックアップファイル名変更（#8）は Bash コマンド内の date フォーマットのみの修正のため、他への影響は最小限
- frontmatter検証失敗時の unclassified フォールバック（#3）により、グループ判定が必ず成功するようになる（全次元失敗のリスクは Phase 1 のみに限定される）
