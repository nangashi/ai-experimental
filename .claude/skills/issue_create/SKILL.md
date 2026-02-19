---
allowed-tools: Bash, Read, AskUserQuestion
description: 対話形式でGitHub Issueを作成し、worktree + tmuxセッションを立ち上げるスキル
disable-model-invocation: true
---

対話形式でユーザーから要件をヒアリングし、GitHub Issueを作成する。
Issue作成後、`tm` コマンドでworktreeとtmuxセッションを自動セットアップする。

## 使い方

```
/issue_create
```

引数なし。対話形式でIssue内容を収集する。

## 前提

- リポジトリ内で実行すること
- ベースブランチ = 現在のブランチ（`gwq add -b` のデフォルト動作）

## ワークフロー

Phase 1（ヒアリング）→ 2（重複チェック）→ 3（スコープ調整）→ 4（確認プレビュー）→ 5（実行）

---

### Phase 1: ヒアリング

以下をテキスト出力し、ユーザーの応答を待つ:

「何を開発したいですか？背景・やりたいこと・制約・完了条件などわかる範囲で教えてください。」

ユーザーの回答から以下を構造化する:

- `{background}`: 背景・動機
- `{tasks}`: 具体的にやること
- `{constraints}`: 制約（なければ「なし」）
- `{acceptance_criteria}`: 受け入れ基準（検証可能な完了条件）
- `{out_of_scope}`: スコープ外（なければ「なし」）

情報が不足している場合は、不足している項目について追加質問する。

Phase 2 へ進む。

---

### Phase 2: 重複チェック

#### Step 1: 類似Issue検索

Phase 1 の `{tasks}` からキーワードを抽出し、`Bash` で以下を実行する:

```
gh issue list --state open --search "{keywords}" --limit 10 --json number,title
```

- 取得失敗時: 「Issue一覧の取得に失敗しました。`gh auth status` を確認してください」と出力し、スキル終了

#### Step 2: 重複判定

類似Issueが0件の場合: Phase 3 へ進む。

類似Issueが1件以上の場合: 以下のテーブルを提示し、`AskUserQuestion` で確認する:

```
以下の類似Issueが見つかりました:

| # | タイトル |
|---|---------|
| #{number} | {title} |
```

選択肢:
- **続行** — 新しいIssueを作成する
- **中止** — 既存Issueを使用する

- 続行: Phase 3 へ
- 中止: 「既存Issueを使用してください」と出力し、スキル終了

---

### Phase 3: スコープ調整

Phase 1 の情報を基に、スコープの大きさを評価する。

受け入れ基準が3つ以上の独立した機能領域にまたがるなど、スコープが大きいと判断した場合:

1. スコープの絞り込みを提案する（どの部分を今回のIssueに含め、何をスコープ外とするか）
2. `AskUserQuestion` で確認する:
   - **採用** — 提案に従ってスコープを絞る
   - **そのまま** — 現在のスコープで進める
3. 採用の場合: スコープ外とした項目を `{out_of_scope}` に追加し、`{tasks}` と `{acceptance_criteria}` を更新する

スコープが適切な場合: そのまま Phase 4 へ進む。

スコープ外とした項目は、後で別途 `/issue_create` で扱う。

---

### Phase 4: 確認プレビュー

#### Step 1: リポジトリ情報の取得

`Bash` で以下を実行する:

```
git branch --show-current
```

`{current_branch}` として保持する。

`Bash` で以下を実行する:

```
git remote get-url origin
```

出力からghqパスを導出し `{repo_id}` として保持する:
- SSH形式 `git@github.com:owner/repo.git` → `github.com/owner/repo`
- HTTPS形式 `https://github.com/owner/repo.git` → `github.com/owner/repo`

いずれのコマンドも失敗した場合: 「Gitリポジトリ内で実行してください」と出力し、スキル終了。

#### Step 2: Issue内容の生成

Phase 1 の情報から以下を生成する:

- `{issue_title}`: `{tasks}` を簡潔な命令形のタイトルにする
- `{issue_body}`: 以下のテンプレートに従って生成する
- `{slug}`: `{issue_title}` から英語の短いスラッグを生成する（小文字、英数字+ハイフン、30文字以内）

**Issueテンプレート**:

```markdown
## 背景

{background}

## やること

{tasks — 箇条書きで}

## 制約

{constraints — なければ「なし」}

## 受け入れ基準

- [ ] {acceptance_criteria — 検証可能な条件をチェックボックス形式で}

## スコープ外

{out_of_scope — なければ「なし」}
```

#### Step 3: 統合プレビューの提示

以下をテキスト出力し、`AskUserQuestion` で確認する:

```
### Issue

**タイトル**: {issue_title}

**本文**:
{issue_body}

### ブランチ

{current_branch} → feature/<number>-{slug}
（Issue番号は作成後に確定します）
```

選択肢:
- **作成** — この内容でIssueを作成する
- **修正** — 修正点を指示する

- 作成: Phase 5 へ
- 修正: ユーザーの修正指示を反映し、Step 3 を再提示する

---

### Phase 5: 実行

#### Step 1: Issue作成

`Bash` で以下を実行する:

```
gh issue create --title "{issue_title}" --body "{issue_body}"
```

- 失敗時: 「Issue作成に失敗しました。`gh auth status` を確認してください」と出力し、スキル終了

出力からIssue番号とURLを取得する。`{issue_number}` と `{issue_url}` として保持する。

#### Step 2: ブランチ名の確定

`{branch_name}` = `feature/{issue_number}-{slug}`

#### Step 3: 完了情報の出力

以下をテキスト出力する:

```
## Issue作成完了

- Issue: {issue_url}
- ブランチ: {branch_name}

tmuxセッションを切り替えます...
```

#### Step 4: worktree + tmuxセッションの立ち上げ

`Bash` で以下を実行する:

```
tm {repo_id} {branch_name}
```

- 失敗時: 「worktreeの作成に失敗しました。手動で `tm {repo_id} {branch_name}` を実行してください」と出力し、スキル終了
