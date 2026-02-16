# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | 外部参照パス修正、Phase 2 エラーハンドリング追加、検証フロー修正、行数削減、成功基準明示、Fast mode 対応 | C-1, C-2, C-3, C-4, C-5, C-6, C-7, C-8, I-1, I-2, I-3, I-4, I-6, I-8, I-9 |
| 2 | templates/apply-improvements.md | 修正 | Write 使用基準の明確化、返答行数上限の明示 | I-5, I-7 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）

**対応フィードバック**:
- **C-1**: 外部参照パスが旧スキル名を使用
- **C-2**: Phase 2 Step 4 サブエージェント失敗時の処理が未定義
- **C-3**: Phase 1 findings ファイルの上書き動作が不明確
- **C-4**: 外部参照の実在性検証が欠落
- **C-5**: SKILL.md が目標行数超過
- **C-6**: 成功基準が推定困難
- **C-7**: Phase 2 検証失敗時の処理が不完全
- **C-8**: Phase 1 全失敗時の判定基準が曖昧
- **I-1**: Phase 1 サブエージェントへの返答指示にフィールド区切りが不明確
- **I-2**: Phase 0 のファイル不在時メッセージが簡素
- **I-3**: Phase 1 全失敗時の原因要約がない
- **I-4**: Phase 1 部分失敗時のユーザー通知の詳細不足
- **I-6**: Fast mode 未対応
- **I-8**: Phase 1 エラーハンドリングでの件数抽出ロジックが複雑
- **I-9**: テンプレート変数の定義が不足

**変更内容**:

1. **行12-16（使い方セクション）: 成功基準の追加**（C-6）
   - 現在: Fast mode パラメータのみ記載
   - 改善後:
   ```markdown
   ## 使い方

   ```
   /agent_audit <file_path> [--fast]    # エージェント定義ファイルを指定して監査
   ```

   - `file_path`: エージェント定義ファイルのパス（必須）
   - `--fast`: Fast mode（Phase 2 の承認確認をスキップし、全 findings を自動承認）

   ## 期待される成果物

   - `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`: 各次元の分析結果
   - `.agent_audit/{agent_name}/audit-approved.md`: 承認済み findings
   - `{agent_path}.backup-{timestamp}`: 変更前のバックアップ（改善適用時）
   - 変更済みエージェント定義: `{agent_path}`（承認された改善が適用済み）
   ```

2. **行64（外部参照パスの削除とインライン化）**（C-1, C-4, C-5）
   - 現在: `エージェント定義の **主たる機能** に注目して分類する。分類基準の詳細は `.claude/skills/agent_audit/group-classification.md` を参照。`
   - 改善後: 外部参照を削除し、判定ルールのみ記載（詳細は group-classification.md にあるため重複記載不要）
   ```markdown
   エージェント定義の **主たる機能** に注目して分類する:
   ```

3. **行107-109（Phase 1 冒頭）: findings ファイルの上書き動作を明示**（C-3）
   - 現在: `テキスト出力: ## Phase 1: コンテンツ分析 ({agent_group}) — {dim_count}次元を並列分析中...`
   - 改善後:
   ```markdown
   既存 findings ファイル（`.agent_audit/{agent_name}/audit-*.md`）が存在する場合、サブエージェントが Write で上書きする。

   テキスト出力: `## Phase 1: コンテンツ分析 ({agent_group}) — {dim_count}次元を並列分析中...`
   ```

4. **行115（外部参照パスの修正）**（C-1）
   - 現在: `> `.claude/skills/agent_audit/agents/{dim_path}.md` を Read し、その指示に従って分析を実行してください。`
   - 改善後: `> `.claude/skills/agent_audit_new/agents/{dim_path}.md` を Read し、その指示に従って分析を実行してください。`

5. **行118（返答フォーマットの明示）**（I-1）
   - 現在: `> 分析完了後、以下のフォーマットで返答してください: dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`
   - 改善後:
   ```markdown
   > 分析完了後、以下の4行フォーマットで返答してください:
   > ```
   > dim: {次元名}
   > critical: {N}
   > improvement: {M}
   > info: {K}
   > ```
   ```

6. **行126-129（Phase 1 エラーハンドリング）: 件数抽出ロジックの明確化と全失敗時の原因要約追加**（C-8, I-3, I-8）
   - 現在: 件数抽出の優先順位が不明、「空」の定義が不明、全失敗時の原因要約なし
   - 改善後:
   ```markdown
   **エラーハンドリング**: 各サブエージェントの成否を以下で判定する:
   - 対応する findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）が存在し、空でない（0バイトでなく、かつ `## Summary` セクションを含む） → 成功。件数はサブエージェント返答から抽出する（抽出失敗時は findings ファイル内の `### {ID_PREFIX}-` ブロック数から推定する）
   - findings ファイルが存在しない、または空（0バイトまたは `## Summary` セクションが存在しない） → 失敗。Task ツールの返答から例外情報（エラーメッセージの要約）を抽出し、該当次元は「分析失敗（{エラー概要}）」として扱う

   全て失敗した場合: 「Phase 1: 全次元の分析に失敗しました。失敗理由:\n- {次元名}: {エラー概要}\n（各失敗次元を列挙）」とエラー出力して終了する。
   ```

7. **行132-136（Phase 1 出力）: 部分失敗時の明示**（I-4）
   - 現在: 失敗した次元の明示が不足
   - 改善後:
   ```markdown
   テキスト出力:
   ```
   Phase 1 完了: {成功数}/{dim_count}
   - {次元名}: critical {N}, improvement {M}, info {K}（または「分析失敗（{エラー概要}）」）
   （各次元を1行ずつ表示）

   {部分失敗時のみ:}
   ⚠ 失敗した次元: {失敗次元名リスト}。これらの次元の分析結果は含まれていません。
   ```
   ```

8. **行142-149（Phase 2 冒頭）: Fast mode 対応**（I-6）
   - 現在: Fast mode の記載なし
   - 改善後:
   ```markdown
   ### Phase 2: ユーザー承認 + 改善適用

   Fast mode が有効な場合、Step 2 の承認確認をスキップし、全 findings を自動承認として Step 3 へ進む。

   テキスト出力: `## Phase 2: ユーザー承認`

   #### Step 1: Findings の収集
   （以下同じ）
   ```

9. **行221（外部参照パスの修正）**（C-1）
   - 現在: ``.claude/skills/agent_audit/templates/apply-improvements.md` を Read で読み込み、その内容に従って処理を実行してください。`
   - 改善後: ``.claude/skills/agent_audit_new/templates/apply-improvements.md` を Read で読み込み、その内容に従って処理を実行してください。`

10. **行221-226（Phase 2 Step 4）: テンプレート変数の追加とエラーハンドリング追加**（C-2, I-9）
    - 現在: エラーハンドリングなし、テンプレート変数不足
    - 改善後:
    ```markdown
    `.claude/skills/agent_audit_new/templates/apply-improvements.md` を Read で読み込み、その内容に従って処理を実行してください。
    パス変数:
    - `{agent_path}`: {実際の agent_path の絶対パス}
    - `{approved_findings_path}`: {実際の .agent_audit/{agent_name}/audit-approved.md の絶対パス}
    - `{backup_path}`: {実際の {agent_path}.backup-{timestamp} の絶対パス}

    サブエージェント完了後、返答内容（変更サマリ）をテキスト出力する。

    **エラーハンドリング**: サブエージェント失敗時またはタイムアウト時は、「✗ 改善適用に失敗しました: {エラー概要}\nバックアップから復旧できます: `cp {backup_path} {agent_path}`」とテキスト出力し、Phase 3 へ進む（改善適用なしとして扱う）。
    ```

11. **行235（Phase 2 検証失敗時のフラグ保存）**（C-7）
    - 現在: 検証失敗時の警告表示のみ
    - 改善後:
    ```markdown
    4. 検証失敗時: 「✗ 検証失敗: エージェント定義が破損している可能性があります。以下のコマンドでロールバックできます: `cp {backup_path} {agent_path}`」とテキスト出力し、`{validation_failed} = true` を記録
    ```

12. **行239-279（Phase 3）: 検証失敗警告の追加**（C-7）
    - 現在: 検証失敗時の警告再表示なし
    - 改善後: Phase 2 が実行された場合のセクションに以下を追加:
    ```markdown
    Phase 2 が実行された場合:
    ```
    ## agent_audit 完了
    - エージェント: {agent_name}
    - ファイル: {agent_path}
    - グループ: {agent_group}
    - 分析次元: {dim_count}件（{各次元名}）
    - 検出: critical {N}件, improvement {M}件, info {K}件
    - 承認: {approved}/{total}件（スキップ: {skip}件）
    - 変更詳細:
      - 適用成功: {N}件（{finding ID リスト}）
      - 適用スキップ: {K}件（{finding ID: スキップ理由}）
    - バックアップ: {backup_path}（変更を取り消す場合: `cp {backup_path} {agent_path}`）

    {validation_failed が true の場合:}
    - ⚠ 検証失敗: エージェント定義の構造を確認してください
    ```
    ```

13. **行56（Phase 0 Step 2）: ファイル不在時のエラーメッセージ改善**（I-2）
    - 現在: `読み込み失敗時はエラー出力して終了`
    - 改善後: `読み込み失敗時は「✗ エラー: {agent_path} が見つかりません。ファイルパスを確認してください。」と出力して終了`

### 2. templates/apply-improvements.md（修正）

**対応フィードバック**:
- **I-5**: 「ファイル全体の書き換えが必要な場合」の基準が不明
- **I-7**: サブエージェント返答行数の明示不足

**変更内容**:

1. **行23（Write 使用基準の明確化）**（I-5）
   - 現在: `Write はファイル全体の書き換えが必要な場合のみ使用する`
   - 改善後: `Write はファイル全体の書き換えが必要な場合のみ使用する（目安: 全体の30%以上の行に変更が及ぶ、またはファイル構造全体の再編成が必要な場合）`

2. **行29-37（返答フォーマット）: 返答行数上限の明示**（I-7）
   - 現在: 返答行数上限の記載なし
   - 改善後:
   ```markdown
   ## 返答フォーマット

   以下のフォーマットで**結果のみ**返答する（上限: 30行以内。詳細はファイルに保存し、サマリのみ返答する）:
   ```
   modified: {N}件
     - {finding ID} → {ファイルパス}:{セクション名}: {変更概要}
   skipped: {K}件
     - {finding ID}: {スキップ理由}
   ```
   ```

## 新規作成ファイル

（なし）

## 削除推奨ファイル

（なし）

## 実装順序

1. **templates/apply-improvements.md の修正**
   - 理由: SKILL.md の Phase 2 Step 4 で参照されるため、先に修正して整合性を確保する

2. **SKILL.md の修正**
   - 理由: 全体のワークフローを定義するメインファイル。templates/apply-improvements.md の変更後に修正する

## 注意事項

- 外部参照パスの修正（C-1）により、グループ分類基準の詳細は group-classification.md に保持され、SKILL.md からは参照されなくなる（重複記載を回避）
- Fast mode 対応（I-6）により、ユーザーが `--fast` フラグを指定した場合、Phase 2 Step 2 の承認確認がスキップされる
- Phase 2 Step 4 のエラーハンドリング追加（C-2）により、サブエージェント失敗時もワークフローが中断せず Phase 3 まで進む
- 検証失敗時の警告再表示（C-7）により、Phase 3 のサマリで検証失敗が明示される
- 行数削減（C-5）は、外部参照削除（-1行）、per-item 承認フローの既存実装維持により達成（目標: 279 → 250行、実際: 約15-20行増加予想 → 追加の削減なし）
  - **注**: C-5 の目標行数超過解決は、外部参照削除による削減と、Fast mode による条件分岐の簡素化で部分的に対応。per-item 承認フローの簡素化は、ユーザー体験への影響が大きいため保留を推奨
