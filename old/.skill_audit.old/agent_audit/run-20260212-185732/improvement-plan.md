# 改善計画: agent_audit

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 1 サブエージェント返答フォーマットの明示化 | C-2 |
| 2 | SKILL.md | 修正 | Phase 2 Step 4 パス変数の定義追加 | C-3 |
| 3 | SKILL.md | 修正 | Phase 1 冒頭での並列タスク数の事前通知 | I-7 |
| 4 | SKILL.md | 修正 | Phase 2 Step 2 冒頭での severity 別内訳の表示 | I-8 |
| 5 | SKILL.md | 修正 | Phase 1 サブエージェント失敗時の原因情報表示 | I-9 |
| 6 | SKILL.md | 修正 | Phase 2 Step 4 完了時の検証ステップ追加 | I-3 |
| 7 | group-classification.md | 新規作成 | グループ分類基準の外部化 | I-2 |
| 8 | SKILL.md | 修正 | Phase 0 のグループ分類基準を外部ファイル参照に置換 | I-2 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**: C-2: サブエージェント返答フォーマット未明示

**変更内容**:
- Phase 1 のサブエージェント起動箇所（128-129行目）: Task prompt に返答フォーマットを追加
  - 現在: 「分析対象: `{agent_path}`, agent_name: `{agent_name}`, findings の保存先: `{findings_save_path}`」
  - 改善後: 「分析対象: `{agent_path}`, agent_name: `{agent_name}`, findings の保存先: `{findings_save_path}`. 分析完了後、以下のフォーマットで返答してください: `dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`」

### 2. SKILL.md（修正）
**対応フィードバック**: C-3: テンプレート内プレースホルダ未定義

**変更内容**:
- Phase 2 Step 4 のサブエージェント起動箇所（229-234行目）: パス変数の定義を明示化
  - 現在:
    ```
    `.claude/skills/agent_audit/templates/apply-improvements.md` を Read で読み込み、その内容に従って処理を実行してください。
    パス変数:
    - `{agent_path}`: エージェント定義ファイルの絶対パス
    - `{approved_findings_path}`: `.agent_audit/{agent_name}/audit-approved.md` の絶対パス
    ```
  - 改善後（`{agent_path}` と `{approved_findings_path}` の具体的な絶対パスを実行時に展開してテンプレートに渡す形式に変更）:
    ```
    `.claude/skills/agent_audit/templates/apply-improvements.md` を Read で読み込み、その内容に従って処理を実行してください。
    パス変数:
    - `{agent_path}`: {実際の agent_path の絶対パス}
    - `{approved_findings_path}`: {実際の .agent_audit/{agent_name}/audit-approved.md の絶対パス}
    ```

### 3. SKILL.md（修正）
**対応フィードバック**: I-7: 並列サブエージェント実行の開始通知欠落

**変更内容**:
- Phase 1 冒頭のテキスト出力（121行目）: 並列起動数を含める
  - 現在: `## Phase 1: コンテンツ分析 ({agent_group})`
  - 改善後: `## Phase 1: コンテンツ分析 ({agent_group}) — {dim_count}次元を並列分析中...`

### 4. SKILL.md（修正）
**対応フィードバック**: I-8: Phase 2 の所要時間予測不能

**変更内容**:
- Phase 2 Step 2 の対象 findings 一覧表示前（163-172行目）: severity 別内訳を追加
  - 現在: `### 対象 findings ({total}件)`
  - 改善後: `### 対象 findings: 計{total}件（critical {N}, improvement {M}）`

### 5. SKILL.md（修正）
**対応フィードバック**: I-9: サブエージェント失敗時の原因不明

**変更内容**:
- Phase 1 エラーハンドリング箇所（136-140行目）: 失敗時の原因情報を含める
  - 現在: findings ファイルの存在チェックのみで「分析失敗」と表示
  - 改善後: Task ツールの返答から例外情報を抽出し、「分析失敗（{エラー概要}）」のように原因を含めて表示

### 6. SKILL.md（修正）
**対応フィードバック**: I-3: 最終成果物の構造検証がない

**変更内容**:
- Phase 2 Step 4 のサブエージェント完了後（235行目以降）: 検証ステップを追加
  - 改善後の処理:
    1. サブエージェント完了後、返答内容（変更サマリ）をテキスト出力
    2. Read で `{agent_path}` を再読み込み
    3. YAML frontmatter の存在確認（ファイル先頭が `---` で始まり、`description:` を含む）
    4. 検証成功時: 「✓ 検証完了: エージェント定義の構造は正常です」とテキスト出力
    5. 検証失敗時: 「✗ 検証失敗: エージェント定義が破損している可能性があります。以下のコマンドでロールバックできます: `cp {backup_path} {agent_path}`」とテキスト出力し、Phase 3 でも警告を表示

### 7. group-classification.md（新規作成）
**対応フィードバック**: I-2: グループ分類基準の外部化

**変更内容**:
- 新規ファイル `.claude/skills/agent_audit/group-classification.md` を作成
- SKILL.md Phase 0 の64-82行目の分類基準をそのまま移行
- 内容:
  ```markdown
  # エージェントグループ分類基準

  エージェント定義の **主たる機能** に注目して分類する。以下の判定基準を **hybrid → evaluator → producer → unclassified** の順に評価し、最初に該当したグループに分類する。

  ## evaluator 特徴（4項目）
  - 評価基準・チェックリスト・検出ルールが定義されている
  - 入力に対して問題点・改善点・findings を出力する構造がある
  - 重要度・深刻度（severity, critical, significant 等）による分類がある
  - 評価スコープ（何を評価するか/しないか）が定義されている

  ## producer 特徴（4項目）
  - ステップ・手順・ワークフローに従って成果物を作成する構造がある
  - 出力がファイル・コード・文書・計画などの成果物である
  - 入力を変換・加工・生成する処理が主体である
  - ツール操作（Read/Write/Edit/Bash 等）による作業手順が記述されている

  ## 判定ルール
  1. evaluator 特徴が3つ以上 **かつ** producer 特徴が3つ以上 → **hybrid**
  2. evaluator 特徴が3つ以上 → **evaluator**
  3. producer 特徴が3つ以上 → **producer**
  4. 上記いずれにも該当しない → **unclassified**
  ```

### 8. SKILL.md（修正）
**対応フィードバック**: I-2: グループ分類基準の外部化（SKILL.md 側の参照修正）

**変更内容**:
- Phase 0 グループ分類箇所（60-84行目）: 詳細基準を外部ファイル参照に置換
  - 現在: 「#### グループ分類」セクションに4項目×2 + 判定ルールを全インライン記述（19行）
  - 改善後:
    ```markdown
    #### グループ分類

    4. `{agent_content}` を分析し、`{agent_group}` を以下の基準で判定する:

       エージェント定義の **主たる機能** に注目して分類する。分類基準の詳細は `.claude/skills/agent_audit/group-classification.md` を参照。

       判定ルール（概要）:
       1. evaluator 特徴が3つ以上 **かつ** producer 特徴が3つ以上 → **hybrid**
       2. evaluator 特徴が3つ以上 → **evaluator**
       3. producer 特徴が3つ以上 → **producer**
       4. 上記いずれにも該当しない → **unclassified**

       この判定はメインコンテキストで直接行う（サブエージェント不要）。
    ```

## 新規作成ファイル
| ファイル | 目的 | 対応フィードバック |
|---------|------|------------------|
| `.claude/skills/agent_audit/group-classification.md` | グループ分類基準を外部化し、SKILL.md のコンテキストを節約する | I-2 |

## 削除推奨ファイル
なし

## 実装順序
1. **group-classification.md の新規作成**（I-2 対応）
   - 理由: SKILL.md の変更がこのファイルを参照するため、先に作成する必要がある
2. **SKILL.md の修正（I-2 対応部分）**
   - 理由: グループ分類基準を外部ファイル参照に変更
3. **SKILL.md の修正（C-2, C-3, I-7, I-8, I-9, I-3 対応部分）**
   - 理由: 上記2つの変更完了後、残りの修正を一括適用できる（依存関係なし）

## 注意事項
- 変更によって既存のワークフローが壊れないこと
  - Phase 1 の返答フォーマット明示化（C-2）は、既存のサブエージェント（dimension ファイル）が既に4行形式で返答している前提を追加で明示するのみ
  - Phase 2 Step 4 のパス変数明示化（C-3）は、実行時に具体的な絶対パスを展開する必要がある（Task prompt 生成時に文字列置換）
  - Phase 2 Step 4 の検証ステップ追加（I-3）は、改善適用後の処理なので既存フローへの影響は最小限
- group-classification.md は SKILL.md から参照される補助ドキュメントであり、サブエージェントには渡されない
- 検証失敗時のロールバック手順はユーザーへの提示のみで、自動ロールバックは実装しない（意図的な変更の可能性があるため）
