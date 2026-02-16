# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | templates/apply-improvements.md | 修正 | パス変数セクションの追加 | C-3: 参照整合性 |
| 2 | SKILL.md | 修正 | 冗長記述の簡素化（18行削減） | C-6: SKILL.md 行数超過 |

## 各ファイルの変更詳細

### 1. templates/apply-improvements.md（修正）
**対応フィードバック**: C-3: 参照整合性: テンプレート内プレースホルダの定義欠落 [stability]

**変更内容**:
- 冒頭（Line 1 の前）: パス変数セクションを追加
  - 追加内容: 以下の「## パス変数」セクションをテンプレート冒頭に挿入
    ```markdown
    ## パス変数
    - `{approved_findings_path}`: 承認済み findings ファイルのパス（`.agent_audit/{agent_name}/audit-approved.md`）
    - `{agent_path}`: エージェント定義ファイルのパス（変更対象）
    - `{backup_path}`: バックアップファイルのパス（`{agent_path}.backup-{timestamp}`）

    ```
  - 現在: `以下の手順で承認済み監査 findings に基づいてエージェント定義を改善してください:`（Line 1）
  - 変更後: 上記のパス変数セクション + 空行 + 現在の Line 1 以降

### 2. SKILL.md（修正）
**対応フィードバック**: C-6: SKILL.md が目標行数を超過 [efficiency]

**変更内容**:
- Phase 0 Step 3（Line 67）: frontmatter チェックの説明を簡素化
  - 現在: `3. ファイル内容の簡易チェック: ファイル先頭に YAML frontmatter（`---` で囲まれたブロック内に `description:` を含む）が存在するか確認する。存在しない場合、「⚠ このファイルにはエージェント定義の frontmatter がありません。エージェント定義ではない可能性があります。」とテキスト出力する（処理は継続する。frontmatter 欠落は警告のみ。グループ分類以降のステップは通常通り実行する）`
  - 変更後: `3. ファイル先頭に YAML frontmatter（`---` と `description:` を含む）が存在するか確認する。存在しない場合、警告を出力するが処理は継続する`

- Phase 2 Step 2a（Line 196-203）: per-item 承認の説明を簡素化
  - 現在:
    ```
    #### Step 2a: Per-item 承認（「1件ずつ確認」選択時のみ）

    各 finding の詳細（ID, title, severity, 次元名, description, evidence, recommendation）をテキスト出力し、`AskUserQuestion` で以下の選択肢を提示:
    - **「承認」**: この指摘を改善計画に含める
    - **「スキップ」**: この指摘を改善計画から除外する
    - **「残りすべて承認」**: この指摘を含め、未確認の全指摘を承認
    - **「キャンセル」**: 全指摘の確認を中止し、Phase 3 へ直行する

    ユーザーが "Other" で修正内容を入力した場合は「修正して承認」として改善計画に含める。
    ```
  - 変更後:
    ```
    #### Step 2a: Per-item 承認（「1件ずつ確認」選択時のみ）

    各 finding を提示し、`AskUserQuestion` で「承認」「スキップ」「残りすべて承認」「キャンセル」を選択させる。"Other" 入力は「修正して承認」として扱う。
    ```

- Phase 3 条件分岐（Line 265-268）: 次のステップ提案の説明を簡素化
  - 現在:
    ```
    **次のステップ**（承認結果に応じて条件分岐）:
    - critical findings を承認・適用した場合: `次のステップ: 再度 /agent_audit {agent_path} で修正結果を確認してください`
    - improvement のみ適用した場合: `次のステップ: /agent_bench {agent_path} で構造最適化を検討できます`
    - 承認が 0 件の場合: 次のステップは表示しない
    ```
  - 変更後:
    ```
    **次のステップ**: critical 適用時は `/agent_audit {agent_path}` で再監査、improvement のみ適用時は `/agent_bench {agent_path}` で構造最適化を検討
    ```

## 新規作成ファイル
（なし）

## 削除推奨ファイル
（なし）

## 実装順序
1. **templates/apply-improvements.md の修正**: パス変数セクションの追加（他ファイルへの影響なし）
2. **SKILL.md の修正**: 冗長記述の簡素化（18行削減目標）

**依存関係**: なし。両ファイルは独立して変更可能。

## 注意事項
- templates/apply-improvements.md: パス変数セクション追加後も既存の手順セクション（Line 1 以降）はそのまま維持する
- SKILL.md: 簡素化により機能や意味が変わらないように注意する。削減目標は 18行だが、無理に行数を削減するために重要な情報を削除しない
- 変更後にファイル構造（frontmatter、見出し階層）が壊れないことを確認する
