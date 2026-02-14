# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 2 検証ステップの詳細をテンプレートに一元化、Phase 1 並列起動の簡潔化、findings-summary.md 利用の明記 | C-1, C-2, I-1 |
| 2 | templates/validate-agent-structure.md | 修正 | 検証ステップの詳細記述をテンプレートに統合 | C-2 |
| 3 | templates/apply-improvements.md | 修正 | 30行超過時の処理を明記 | C-4 |
| 4 | templates/collect-findings.md | 修正 | findings-summary.md に Findings List セクションを追加し、ID/severity/title/次元名を含める | I-1 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**:
- C-1: SKILL.md超過 [efficiency]
- C-2: 検証ステップの冗長性 [efficiency]
- I-1: findings-summary.md の Read と一覧提示の接続が不明確 [architecture]

**変更内容**:

#### 変更1-1: Phase 1 並列起動の手順簡潔化（行173-199）
- **現在の記述**:
  ```
  各次元の開始メッセージを出力:
  ```
  - {次元名1} 分析開始
  - {次元名2} 分析開始
  ...
  ```

  `{dim_count}` 個の `Task` を同一メッセージ内で並列起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）。各次元完了時にリアルタイムで「✓ {次元名} 完了」と出力する。

  各次元について、以下の Task prompt を使用する:

  > `.claude/skills/agent_audit_new/agents/{dim_path}.md` を Read し、その指示に従って分析を実行してください。
  > 分析対象: `{agent_path}`, agent_name: `{agent_name}`
  > findings の保存先: `{findings_save_path}`（= `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` の絶対パス）
  > 分析完了後、以下の4行フォーマットで返答してください（件数は findings ファイルに保存した実際の件数を記載すること）:
  > ```
  > dim: {次元名}
  > critical: {N}
  > improvement: {M}
  > info: {K}
  > ```

  `{dim_path}` は dimensions テーブルの各エントリ（例: `evaluator/criteria-effectiveness`）。
  `{ID_PREFIX}` は各次元の Finding ID Prefix（CE, IC, SA, DC, WC, OF）。
  ```

- **改善後の記述**:
  ```
  テキスト出力: 各次元の開始メッセージ（`- {次元名1} 分析開始`, `- {次元名2} 分析開始`, ...）

  `{dim_count}` 個の `Task` を同一メッセージ内で並列起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）。各 Task prompt: `.claude/skills/agent_audit_new/agents/{dim_path}.md` を Read し、指示に従って分析を実行（分析対象: `{agent_path}`, agent_name: `{agent_name}`, findings 保存先: `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` の絶対パス）。返答フォーマット: 4行（`dim: {次元名}`, `critical: {N}`, `improvement: {M}`, `info: {K}`）

  各次元完了時: リアルタイムで「✓ {次元名} 完了」と出力
  ```

  削減行数: 約13行

#### 変更1-2: Phase 2 検証ステップの詳細削除（行336-362）
- **現在の記述**:
  ```
  #### 検証ステップ

  **analysis_path の存在判定**: Bash で `.skill_audit/` ディレクトリを検索し、最新の `run-*` ディレクトリの `analysis.md` を取得する:
  - `ls -td .skill_audit/*/run-* 2>/dev/null | head -1` で最新 run ディレクトリを取得
  - 取得成功時: `{analysis_path}` = `{最新runディレクトリ}/analysis.md` の絶対パスを設定
  - 取得失敗時または analysis.md が存在しない場合: `{analysis_path}` は省略（テンプレートに渡さない）

  改善適用完了後、Task ツールでサブエージェントに検証を委譲する（`subagent_type: "general-purpose"`, `model: "haiku"`）:

  > `.claude/skills/agent_audit_new/templates/validate-agent-structure.md` を Read で読み込み、その内容に従って処理を実行してください。
  > パス変数:
  > - `{agent_path}`: {実際の agent_path の絶対パス}
  > - `{backup_path}`: {Step 4 で生成されたバックアップファイルの完全な絶対パス}
  > - `{analysis_path}`: {存在する場合のみ: 上記で取得した analysis.md の絶対パス}

  サブエージェント失敗時: 「✗ エラー: 検証処理に失敗しました」とエラー出力、Phase 3 へ進む。

  サブエージェント完了後、返答から `validation_status`, `rollback_executed` を抽出する（正規表現: `validation_status: (.+)`, `rollback_executed: (.+)`）。

  `validation_status` が "failed" の場合:
  - `{validation_failed} = true` を記録
  - `rollback_executed` が "true" の場合: 「✓ 自動ロールバック完了」とテキスト出力
  - `rollback_executed` が "false" の場合: 「✗ 検証失敗: エージェント定義が破損している可能性があります。以下のコマンドでロールバックできます: `cp {backup_path} {agent_path}`」とテキスト出力

  `validation_status` が "passed" の場合:
  - 「✓ 検証完了: エージェント定義の構造は正常です」とテキスト出力
  ```

- **改善後の記述**:
  ```
  #### 検証ステップ

  **analysis_path の存在判定**: Bash で `ls -td .skill_audit/*/run-* 2>/dev/null | head -1` を実行し、最新 run ディレクトリ内の `analysis.md` 絶対パスを取得（失敗時は省略）

  Task ツールで検証サブエージェントに委譲（`subagent_type: "general-purpose"`, `model: "haiku"`）:

  > `.claude/skills/agent_audit_new/templates/validate-agent-structure.md` を Read で読み込み、その内容に従って処理を実行してください。
  > パス変数:
  > - `{agent_path}`: {実際の agent_path の絶対パス}
  > - `{backup_path}`: {Step 4 で生成されたバックアップファイルの完全な絶対パス}
  > - `{analysis_path}`: {存在する場合のみ: 上記で取得した analysis.md の絶対パス}

  サブエージェント完了後、返答から `validation_status`, `rollback_executed` を抽出し、条件分岐でテキスト出力を行う（検証失敗時のロールバック確認、検証成功時の正常メッセージ）。サブエージェント失敗時: 「✗ エラー: 検証処理に失敗しました」とエラー出力、Phase 3 へ進む。
  ```

  削減行数: 約13行

#### 変更1-3: Phase 2 Step 2 での findings-summary.md 利用の明記（行276-286）
- **現在の記述**:
  ```
  #### Step 2: 一覧提示 + 承認方針の選択

  対象 findings の一覧をテキスト出力する:
  ```
  ### 対象 findings: 計{total}件（critical {N}, improvement {M}）
  | # | ID | severity | title | 次元 |
  |---|-----|----------|-------|------|
  | 1 | {ID} | {severity} | {title} | {次元名} |
  ...
  ```
  ```

- **改善後の記述**:
  ```
  #### Step 2: 一覧提示 + 承認方針の選択

  findings-summary.md の「## Findings List」セクションから ID/severity/title/次元名を抽出し、対象 findings の一覧をテキスト出力する:
  ```
  ### 対象 findings: 計{total}件（critical {N}, improvement {M}）
  | # | ID | severity | title | 次元 |
  |---|-----|----------|-------|------|
  | 1 | {ID} | {severity} | {title} | {次元名} |
  ...
  ```
  ```

#### C-6 への対応: スコープ外として実装しない
- **理由**: C-6（バックアップの `.prev` → `.prev-{timestamp}` 変更）は検証結果で「スコープ外として未対応」とされており、今回の改善計画には含めない

### 2. templates/validate-agent-structure.md（修正）
**対応フィードバック**: C-2: 検証ステップの冗長性 [efficiency]

**変更内容**:

#### 変更2-1: 検証ステップの詳細手順をテンプレートに追加（行10-49）
- **現在の記述**: 簡潔な手順のみ記載（Step 1-5）
- **改善後の記述**: SKILL.md から移行した詳細手順を統合
  - Step 3 の検証結果判定に詳細な条件を追加
  - Step 4 の自動ロールバックに Bash コマンド例を追加
  - Step 5 の返答に親プロセスでのパース方法を追加（`validation_status` と `rollback_executed` の抽出方法、条件分岐の詳細）

追加内容（Step 5 の返答セクションに追記）:
```markdown
## 親プロセスでのパース方法

返答から以下の情報を抽出する（正規表現: `validation_status: (.+)`, `rollback_executed: (.+)`）:

- `validation_status` が "failed" の場合:
  - `{validation_failed} = true` を記録
  - `rollback_executed` が "true" の場合: 「✓ 自動ロールバック完了」とテキスト出力
  - `rollback_executed` が "false" の場合: 「✗ 検証失敗: エージェント定義が破損している可能性があります。以下のコマンドでロールバックできます: `cp {backup_path} {agent_path}`」とテキスト出力

- `validation_status` が "passed" の場合:
  - 「✓ 検証完了: エージェント定義の構造は正常です」とテキスト出力
```

### 3. templates/apply-improvements.md（修正）
**対応フィードバック**: C-4: 出力フォーマット決定性: サブエージェント返答の曖昧さ [stability]

**変更内容**:

#### 変更3-1: 30行超過時の処理を明記（行36）
- **現在の記述**: `以下のフォーマットで**結果のみ**返答する（上限: 30行以内。詳細はファイルに保存し、サマリのみ返答する）:`
- **改善後の記述**: `以下のフォーマットで**結果のみ**返答する（上限: 30行以内。30行を超える場合は重要度順に上位30行まで記載し、残りは `...（他 N 件）` と省略する）:`

### 4. templates/collect-findings.md（修正）
**対応フィードバック**: I-1: findings-summary.md の Read と一覧提示の接続が不明確 [architecture]

**変更内容**:

#### 変更4-1: findings-summary.md に Findings List セクションを追加（行18-31）
- **現在の記述**:
  ```markdown
  ```markdown
  # findings サマリ

  | severity | 次元 | title |
  |----------|------|-------|
  | critical | XX | ... |
  | improvement | YY | ... |

  ## 統計
  - total: {N}件
  - critical: {C}件
  - improvement: {I}件
  ```
  ```

- **改善後の記述**:
  ```markdown
  ```markdown
  # findings サマリ

  ## Findings List
  | # | ID | severity | title | 次元 |
  |---|-----|----------|-------|------|
  | 1 | {finding ID} | critical | {title} | {次元名} |
  | 2 | {finding ID} | improvement | {title} | {次元名} |
  ...

  ## 統計
  - total: {N}件
  - critical: {C}件
  - improvement: {I}件
  ```
  ```

- **手順2の変更**: findings の抽出時に ID も抽出する（`severity:`, `title:` に加えて finding の先頭行から ID を抽出）

## 新規作成ファイル
（新規作成は不要）

## 削除推奨ファイル
（削除推奨ファイルなし）

## 実装順序
1. **templates/collect-findings.md**: findings-summary.md の出力形式変更（Findings List セクションに ID を追加）
   - 理由: SKILL.md Phase 2 Step 2 が findings-summary.md の Findings List セクションを参照するため、先に形式を整備する
2. **SKILL.md**: Phase 1 簡潔化、Phase 2 Step 2 の findings-summary.md 利用明記、Phase 2 検証ステップ簡潔化
   - 理由: templates/collect-findings.md の変更に依存（Findings List セクションが存在することを前提とする記述を追加）
3. **templates/validate-agent-structure.md**: 検証ステップ詳細の追加
   - 理由: SKILL.md から移行した詳細手順をテンプレートに統合（SKILL.md の変更後に実施）
4. **templates/apply-improvements.md**: 30行超過時の処理明記
   - 理由: 他の変更と独立しており、いつ実施しても影響なし

## 注意事項
- SKILL.md の変更で約26行削減予定（Phase 1 で13行、検証ステップで13行削減）。現在392行 → 約366行となり、目標値250行には到達しないが、改善方向
- templates/validate-agent-structure.md には親プロセスでのパース方法を追記し、検証ステップの詳細をテンプレートに一元化
- findings-summary.md の形式変更により、Phase 2 Step 2 で ID/severity/title/次元名の情報源が明確化される
- C-6（`.prev` のタイムスタンプ化）は検証結果で「スコープ外」とされているため、今回の改善計画には含めない
