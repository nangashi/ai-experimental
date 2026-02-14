# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | バックアップ作成失敗時の検証ロジック追加 | C-1 |
| 2 | SKILL.md | 修正 | frontmatter_warning の状態保持をファイル経由に変更 | C-2 |
| 3 | SKILL.md | 修正 | Phase 0 の既存ファイル削除範囲を拡大 | C-3 |
| 4 | SKILL.md | 修正 | バックアップファイル名の重複チェック追加 | C-4 |
| 5 | SKILL.md | 修正 | frontmatter 検証の精度向上 | C-5 |
| 6 | templates/collect-findings.md | 修正 | findings-summary.md に description/evidence/recommendation を含める | I-1 |

## 変更ステップ

### Step 1: C-1: バックアップ作成失敗時の処理欠落
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_audit_new/SKILL.md
**変更内容**:
- 263行目付近: `**バックアップ作成**: 改善適用前に Bash で cp {agent_path} {agent_path}.backup-$(date +%Y%m%d-%H%M%S) を実行し、{backup_path} を記録する。`
  → 以下に変更:
  ```
  **バックアップ作成**: 改善適用前に以下を実行する:
  1. Bash で `cp {agent_path} {agent_path}.backup-$(date +%Y%m%d-%H%M%S)` を実行し、`{backup_path}` を記録する
  2. バックアップファイルの存在確認: `test -f {backup_path}` を実行
  3. 存在確認失敗時: 「✗ バックアップ作成に失敗しました。改善適用を中止します。」とテキスト出力し、Phase 3 へ直行する
  ```

### Step 2: C-2: データフロー断絶リスク: frontmatter_warning 変数の状態保持
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_audit_new/SKILL.md
**変更内容**:
- 90行目: `存在しない場合、警告フラグ {frontmatter_warning} を true に設定し、「⚠ このファイルにはエージェント定義の frontmatter がありません。エージェント定義ではない可能性があります。」とテキスト出力する（処理は継続する）`
  → 以下に変更:
  ```
  存在しない場合、`.agent_audit/{agent_name}/frontmatter-warning.txt` を Write で作成し、「⚠ このファイルにはエージェント定義の frontmatter がありません。エージェント定義ではない可能性があります。」とテキスト出力する（処理は継続する）
  ```

- 114行目: `rm -f .agent_audit/{agent_name}/audit-*.md`
  → 以下に変更:
  ```
  rm -f .agent_audit/{agent_name}/audit-*.md .agent_audit/{agent_name}/frontmatter-warning.txt
  ```

- 299行目: `{frontmatter_warning} が true の場合:`
  → 以下に変更:
  ```
  `.agent_audit/{agent_name}/frontmatter-warning.txt` が存在する場合:
  ```

- 316行目: `{frontmatter_warning} が true の場合:`
  → 以下に変更:
  ```
  `.agent_audit/{agent_name}/frontmatter-warning.txt` が存在する場合:
  ```

### Step 3: C-3: Phase 0 の再実行時のファイル削除の不完全性
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_audit_new/SKILL.md
**変更内容**:
- 114行目: `既存 findings ファイルを削除: rm -f .agent_audit/{agent_name}/audit-*.md（冪等性保証）`
  → 以下に変更:
  ```
  既存の出力ファイルをクリア: `rm -rf .agent_audit/{agent_name}/* 2>/dev/null || true`（冪等性保証）
  ```

### Step 4: C-4: バックアップファイル名の重複チェック
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_audit_new/SKILL.md
**変更内容**:
- 263行目付近（Step 1 の変更後）: バックアップ作成ロジックを以下に変更:
  ```
  **バックアップ作成**: 改善適用前に以下を実行する:
  1. バックアップファイル名を生成: `{agent_path}.backup-$(date +%Y%m%d-%H%M%S)`
  2. 同名ファイルの存在確認: `test -f {backup_path}` を実行
  3. 既に存在する場合: `{agent_path}.backup-$(date +%Y%m%d-%H%M%S)-$(date +%N | cut -c1-3)` に変更（ミリ秒精度を追加）
  4. Bash で `cp {agent_path} {backup_path}` を実行
  5. バックアップファイルの存在確認: `test -f {backup_path}` を実行
  6. 存在確認失敗時: 「✗ バックアップ作成に失敗しました。改善適用を中止します。」とテキスト出力し、Phase 3 へ直行する
  ```

### Step 5: C-5: frontmatter 検証の精度
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_audit_new/SKILL.md
**変更内容**:
- 286-288行目:
  ```
  1. Read で {agent_path} を再読み込み
  2. YAML frontmatter の存在確認（ファイル先頭が --- で始まり、description: を含む）
  3. 検証成功時: 「✓ 検証完了: エージェント定義の構造は正常です」とテキスト出力
  ```
  → 以下に変更:
  ```
  1. Read で {agent_path} を再読み込み（先頭20行のみ読み込み）
  2. YAML frontmatter の詳細検証:
     - 1行目が `---` で始まる
     - 2～19行目の範囲に再度 `---` が出現する（終了マーカー）
     - 開始マーカーと終了マーカーの間に `description:` 行が存在する
     - `description:` 行の値部分が空でない（例: `description:` のみの行、`description: ""` は NG）
  3. 検証成功時: 「✓ 検証完了: エージェント定義の構造は正常です」とテキスト出力
  ```

### Step 6: I-1: Phase 2 Step 2a の per-item 承認ループで findings 詳細の参照方法
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_audit_new/templates/collect-findings.md
**変更内容**:
- 13-20行目:
  ```
  2. 各ファイルを Read し、`### {ID}:` ブロックを抽出する
  3. 各ブロックから以下の情報を抽出する:
     - ID: ブロックの見出し（例: `CE-001`）
     - severity: `**Severity**:` 行の値（critical / improvement / info）
     - title: ブロックの見出しの `:` 以降の部分
     - 次元名: ファイル名から導出（`audit-CE.md` → `CE`）
  4. severity が `critical` または `improvement` の finding のみをリストに含める
  ```
  → 以下に変更:
  ```
  2. 各ファイルを Read し、`### {ID}:` ブロックを抽出する
  3. 各ブロックから以下の情報を抽出する:
     - ID: ブロックの見出し（例: `CE-001`）
     - severity: `**Severity**:` 行の値（critical / improvement / info）
     - title: ブロックの見出しの `:` 以降の部分
     - description: `**Description**:` 行以降、次の `**` 見出しまでの内容
     - evidence: `**Evidence**:` 行以降、次の `**` 見出しまでの内容
     - recommendation: `**Recommendation**:` 行以降、次の `###` または `##` 見出しまでの内容
     - 次元名: ファイル名から導出（`audit-CE.md` → `CE`）
  4. severity が `critical` または `improvement` の finding のみをリストに含める
  ```

- 43-52行目:
  ```
  # Findings Summary

  ## 対象: {total}件（critical {M}, improvement {K}）

  | # | ID | severity | title | 次元 |
  |---|-----|----------|-------|------|
  | 1 | {ID} | {severity} | {title} | {次元名} |
  | 2 | {ID} | {severity} | {title} | {次元名} |
  ...
  ```
  → 以下に変更:
  ```
  # Findings Summary

  ## 対象: {total}件（critical {M}, improvement {K}）

  | # | ID | severity | title | 次元 |
  |---|-----|----------|-------|------|
  | 1 | {ID} | {severity} | {title} | {次元名} |
  | 2 | {ID} | {severity} | {title} | {次元名} |
  ...

  ## 詳細

  ### {#}: {ID}: {title}
  - **Severity**: {severity}
  - **次元**: {次元名}
  - **Description**: {description}
  - **Evidence**: {evidence}
  - **Recommendation**: {recommendation}

  （全 finding について同様に記述）
  ```

## 新規作成ファイル
（該当なし）

## 削除推奨ファイル
（該当なし）
