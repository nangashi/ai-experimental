---
allowed-tools: Bash, Glob, Grep, Read, Write, Edit, Task, AskUserQuestion
description: 設計に基づきステップ実装・テスト・レビュー・PR Ready化を行うスキル
---

設計ドキュメント（design.md）に基づき、実装ステップ計画・ステップごとの実装・テスト・レビューを行い、PRをReady for Reviewにします。

## 使い方

```
/issue_implement 123
```

Issue番号を引数に指定。`.tasks/123/` から設計情報とPR番号を読み取り、ブランチをcheckoutして実装を開始する。

前提:
- `/issue_design 123` が完了済みであること
- `.tasks/123/design.md` がユーザーレビュー済みであること

## コンテキスト節約の原則

1. **参照ファイルは使用するPhaseでのみ読み込む**（先読みしない）
2. **大量コンテンツの生成はサブエージェントに委譲する**
3. **サブエージェントからの返答は最小限にする**（詳細はファイルに保存させる）
4. **親コンテキストには要約・メタデータのみ保持する**
5. **サブエージェント間のデータ受け渡しはファイル経由で行う**（親を中継しない）

## アーキテクチャ方針

- **テンプレート方式**: 各フェーズの詳細指示はtemplatesのmdファイルに外部化
- **ステップ分割実装**: design.mdから実装ステップを抽出し、ステップごとにサブエージェントに委譲
- **親がテスト実行**: サブエージェントはコード変更のみ。テスト実行・結果判定は親が担当
- **gh CLIは親が実行**: サブエージェントはファイル生成のみ担当
- **異常系**: テストリトライとレビューループに上限回数を設定。超過時は状況報告+次アクション明示でスキル終了

## ワークフロー

Phase 0 で設計・PR情報を読み取りレジューム判定を行い、Phase 1 で実装ステップ計画を作成し、Phase 2 でステップごとに実装・テストを行う。

**v0.3**: Phase 0 〜 Phase 5 実装済み。

---

### Phase 0: 設計読み取り・レジューム判定

#### Issue番号の取得

1. 引数からIssue番号を取得する
   - 未指定の場合は `AskUserQuestion` で確認する

#### state.md の読み取り

2. `.tasks/{issue_number}/state.md` を Read で読み込む
   - 不在の場合: 「issue_design が未完了です。`/issue_design {issue_number}` を先に実行してください」と出力し、スキル終了

3. state.md に `pr_number` と `branch` があるか確認する
   - なし: 「issue_design が未完了です（PR未作成）。`/issue_design {issue_number}` を先に実行してください」と出力し、スキル終了

#### PR情報取得・ブランチcheckout

4. `Bash` で PR 情報を取得する:
   ```
   gh pr view {pr_number} --json headRefName,baseRefName
   ```
   - 取得失敗時: 「PR #{pr_number} の取得に失敗しました。PR番号を確認してください」と出力し、スキル終了

4.5. `Bash` で Issue タイトルを取得する:
   ```
   gh issue view {issue_number} --json title --jq '.title'
   ```
   - 取得した値を `{issue_title}` として保持する

5. `Bash` でブランチをcheckoutする:
   ```
   git checkout {branch}
   ```
   - 失敗時: `git fetch origin && git checkout {branch}` を試行する
   - それでも失敗: 「ブランチ {branch} のcheckoutに失敗しました」と出力し、スキル終了

#### コンフリクトチェック

6. `Bash` でベースブランチとのコンフリクトを確認する:
   ```
   git fetch origin {baseRefName} && git merge --no-commit --no-ff origin/{baseRefName}
   ```
   - コンフリクトあり: `git merge --abort` を実行し、「ベースブランチとのコンフリクトが検出されました。手動で rebase/merge を解決してから `/issue_implement {issue_number}` を再実行してください」と出力し、スキル終了
   - コンフリクトなし: `git merge --abort` を実行し（マージ自体は行わない）、続行する

#### design.md の確認

7. `.tasks/{issue_number}/design.md` を Read で読み込む
   - 不在の場合: 「design.md がありません。`/issue_design {issue_number}` を再実行してください」と出力し、スキル終了

#### state.md の phase によるルーティング

8. phase に応じて以下にルーティングする:

   | phase | ルーティング先 |
   |-------|-------------|
   | `draft_pr_created` | Phase 1 へ |
   | `plan_done`（completed_steps なし） | Phase 2 ステップ1 へ |
   | `plan_done`（completed_steps あり） | 下記「レジューム確認」 |
   | `implementation_done` / `review_in_progress` | Phase 3 へ |
   | `pr_ready` / `feedback_in_progress` | Phase 5 へ |
   | 上記以外 | 「現在の phase は `{phase}` です。`/issue_design {issue_number}` を先に完了してください」と出力し、スキル終了 |

#### レジューム確認（completed_steps あり）

9. completed_steps から最後に完了したステップ番号 `{last_completed}` を取得する
10. `AskUserQuestion` で確認する:
    - 「ステップ {last_completed + 1} で前回テスト/lint 失敗により中断しました。」
    - 選択肢:
      - **修正済み** — 次のステップから再開する
      - **未修正** — 同じステップを再試行する
11. 修正済みの場合: completed_steps に `{last_completed + 1}` を追加し、`{last_completed + 2}` から Phase 2 へ
12. 未修正の場合: `{last_completed + 1}` から Phase 2 へ

---

### Phase 1: 実装ステップ計画

#### ステップ1: 計画生成（サブエージェントに委譲）

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/issue_implement/templates/phase1-plan.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{design_path}`: `.tasks/{issue_number}/design.md` の絶対パス
- `{plan_save_path}`: `.tasks/{issue_number}/implementation-plan.md` の絶対パス
- `{issue_number}`: Issue番号
- `{issue_title}`: Issueタイトル

サブエージェントの返答: `result` + `total_steps` + `test_command` + `lint_command` + `format_command` + `summary`

#### ステップ2: 結果処理

1. サブエージェントが返した計画サマリをユーザーにテキスト出力する
2. `.tasks/{issue_number}/implementation-plan.md` が保存されていることを Read で確認する
3. `.tasks/{issue_number}/state.md` を Edit で更新する: `phase: plan_done`
4. 返答から `{test_command}`, `{lint_command}`, `{format_command}` を保持する
5. 以下を出力する:
   ```
   ## Phase 1 完了

   - 計画: .tasks/{issue_number}/implementation-plan.md
   - ステップ数: {total_steps}

   Phase 2（ステップ実装）に進みます。
   ```
6. Phase 2 へ進む

---

### Phase 2: ステップ実装

#### 準備

1. `.tasks/{issue_number}/implementation-plan.md` を Read し、ステップ一覧とツーリングコマンドを取得する
   - Phase 1 から直接来た場合は保持している値を使用
   - レジュームの場合は implementation-plan.md の「ツーリング」セクションから取得
2. `{start_step}` を決定する（Phase 0 から渡された値、または 1）
3. `{total_steps}` を決定する

#### ステップループ

`{start_step}` から `{total_steps}` まで、各ステップ `{N}` について以下を実行する:

テキスト出力: `### Step {N}/{total_steps}: {ステップ名}`

##### a. サブエージェント実装

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/issue_implement/templates/phase2-implement-step.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{design_path}`: `.tasks/{issue_number}/design.md` の絶対パス
- `{plan_path}`: `.tasks/{issue_number}/implementation-plan.md` の絶対パス
- `{step_number}`: {N}
- `{error_context}`: なし

サブエージェント完了後、変更サマリをテキスト出力する。

##### b. lint/format 実行

`{format_command}` と `{lint_command}` がともに「なし」の場合はスキップする。

1. `{format_command}` が「なし」でない場合、`Bash` で実行する
2. `{lint_command}` が「なし」でない場合、`Bash` で実行する
3. 修正不能なエラーがある場合 → リトライ（下記 d.）

##### c. テスト実行

`{test_command}` が「なし」の場合:
- 「テストコマンドが検出されませんでした。テストをスキップします」と警告出力する
- ステップ e. へ進む

1. `Bash` で `{test_command}` を実行する
2. 成功 → ステップ e. へ
3. 失敗 → 設計問題判定

**設計問題判定**:
テスト失敗の内容から設計自体の問題かを判定する:
- 設計の前提条件と矛盾するエラー、API仕様の不整合 → 設計の問題
- 実装のバグ、型エラー、ロジックミス → 実装の問題

設計の問題の場合:
- 「設計の問題が検出されました: {詳細}。`/issue_design {issue_number}` で設計を修正してから再実行してください」と出力し、スキル終了

実装の問題の場合:
- リトライ（下記 d.）

##### d. リトライ（上限2回/ステップ）

`{retry_count}` が 2 未満の場合:
1. `{retry_count}` += 1
2. `Task` ツールで `templates/phase2-implement-step.md` に委譲する（`{error_context}` に lint/test エラー出力を含める）
3. ステップ b.（lint/format）に戻る

`{retry_count}` が 2 以上の場合:
- 「ステップ {N} でテスト/lint が通過しませんでした。詳細:\n{エラー出力}\n\n手動修正後に `/issue_implement {issue_number}` を再実行してください」と出力し、スキル終了

##### e. コミット

1. サブエージェントの返答から `{files_list}` を取得する
2. `Bash` でコミットする:
   ```
   git add {files_list の各ファイル} && git commit -m "feat(#{issue_number}): step {N} - {ステップ名}"
   ```

##### f. state.md 更新

1. `.tasks/{issue_number}/state.md` を Edit で更新する: `completed_steps` に `{N}` を追加
   - 形式: `completed_steps: 1,2,3`（カンマ区切り）

#### ループ完了後

1. `Bash` で `git push` を実行する
2. `.tasks/{issue_number}/state.md` を Edit で更新する: `phase: implementation_done`
3. 以下を出力してスキル終了:
   ```
   ## Phase 2 完了

   - 全 {total_steps} ステップ実装完了
   - ブランチ: {branch}

   Phase 3（実装レビュー）に進みます。
   ```
4. Phase 3 へ進む

---

### Phase 3: 実装レビュー

#### ステップ0: 準備

1. state.md の phase が `implementation_done` の場合、Edit で `phase: review_in_progress` に更新する
2. ツーリングコマンドを取得する:
   - Phase 2 から直接来た場合は保持している値を使用
   - レジュームの場合は `.tasks/{issue_number}/implementation-plan.md` の「ツーリング」セクションから取得
3. `.tasks/{issue_number}/state.md` から `review_loop` を読み取る（なければ 0）。`{review_loop}` として保持する
4. `{baseRefName}` は Phase 0 で取得済みの値を使用

#### ステップ1: diff取得

1. `Bash` で変更差分をファイルに保存する:
   ```
   git diff origin/{baseRefName}...HEAD > .tasks/{issue_number}/code-diff.txt
   ```

#### ステップ2: 並列レビュー実行

以下の6つを `Task` ツールで **1つのメッセージで並列に** 起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

| 観点 | agent定義 | 結果保存先 |
|------|----------|-----------|
| correctness | `agents/correctness-code-reviewer.md` | `.tasks/{issue_number}/code-review-correctness.md` |
| security | `agents/security-code-reviewer.md` | `.tasks/{issue_number}/code-review-security.md` |
| performance | `agents/performance-code-reviewer.md` | `.tasks/{issue_number}/code-review-performance.md` |
| maintainability | `agents/maintainability-code-reviewer.md` | `.tasks/{issue_number}/code-review-maintainability.md` |
| test | `agents/test-code-reviewer.md` | `.tasks/{issue_number}/code-review-test.md` |
| design-conformance | `agents/design-conformance-code-reviewer.md` | `.tasks/{issue_number}/code-review-design-conformance.md` |

各レビューアーへのプロンプト:

`.claude/skills/issue_implement/templates/phase3-code-review.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{perspective}`: {観点名}
- `{agent_definition_path}`: `.claude/skills/issue_implement/agents/{perspective}-code-reviewer.md` の絶対パス
- `{design_path}`: `.tasks/{issue_number}/design.md` の絶対パス
- `{plan_path}`: `.tasks/{issue_number}/implementation-plan.md` の絶対パス
- `{diff_path}`: `.tasks/{issue_number}/code-diff.txt` の絶対パス
- `{findings_save_path}`: `.tasks/{issue_number}/code-review-{perspective}.md` の絶対パス

6件全ての Task 完了後、各返答のサマリをテキスト出力する。

#### ステップ3: レビュー結果統合

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/issue_implement/templates/phase3-consolidate-reviews.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{review_paths}`: `.tasks/{issue_number}/code-review-correctness.md`, `.tasks/{issue_number}/code-review-security.md`, `.tasks/{issue_number}/code-review-performance.md`, `.tasks/{issue_number}/code-review-maintainability.md`, `.tasks/{issue_number}/code-review-test.md`, `.tasks/{issue_number}/code-review-design-conformance.md` の絶対パスリスト
- `{consolidated_save_path}`: `.tasks/{issue_number}/code-review-consolidated.md` の絶対パス

サブエージェントの返答: `verdict` + `has_design_issues` + `critical` + `significant` + `total` + `summary`

#### ステップ4: 結果に応じた処理

**verdict: pass の場合**:
1. レビュー結果サマリをユーザーにテキスト出力する
2. Phase 4 へ進む

**verdict: needs_revision の場合**:
1. レビュー結果サマリ（Critical/Significant 指摘一覧）をユーザーにテキスト出力する

2. `has_design_issues` が true の場合:
   - 「設計自体の問題が検出されました。`.tasks/{issue_number}/code-review-consolidated.md` を確認し、`/issue_design {issue_number}` で設計を修正してから再実行してください」と出力し、スキル終了

3. `{review_loop}` が 3 以上の場合:
   - 「実装レビューで指摘が解消されませんでした（{review_loop}回試行）。`.tasks/{issue_number}/code-review-consolidated.md` を確認し、手動で修正してから `/issue_implement {issue_number}` を再実行してください」と出力し、スキル終了

4. ステップ5 へ進む

#### ステップ5: コード修正（サブエージェントに委譲）

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/issue_implement/templates/phase3-fix-code.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{design_path}`: `.tasks/{issue_number}/design.md` の絶対パス
- `{plan_path}`: `.tasks/{issue_number}/implementation-plan.md` の絶対パス
- `{consolidated_path}`: `.tasks/{issue_number}/code-review-consolidated.md` の絶対パス
- `{error_context}`: なし

修正サマリをテキスト出力する。`{retry_count}` = 0 とする。

#### ステップ6: lint/format + テスト

##### a. lint/format 実行

`{format_command}` と `{lint_command}` がともに「なし」の場合はスキップする。

1. `{format_command}` が「なし」でない場合、`Bash` で実行する
2. `{lint_command}` が「なし」でない場合、`Bash` で実行する
3. 修正不能なエラーがある場合 → リトライ（下記 c.）

##### b. テスト実行

`{test_command}` が「なし」の場合はスキップしてステップ7へ。

1. `Bash` で `{test_command}` を実行する
2. 成功 → ステップ7 へ
3. 失敗 → リトライ（下記 c.）

##### c. リトライ（上限2回）

`{retry_count}` が 2 未満の場合:
1. `{retry_count}` += 1
2. `Task` ツールで `templates/phase3-fix-code.md` に委譲する（`{error_context}` に lint/test エラー出力を含める）
3. ステップ6 a.（lint/format）に戻る

`{retry_count}` が 2 以上の場合:
- 「レビュー修正後のテスト/lint が通過しませんでした。詳細:\n{エラー出力}\n\n手動修正後に `/issue_implement {issue_number}` を再実行してください」と出力し、スキル終了

#### ステップ7: コミット + 再レビュー

1. サブエージェントの返答から `{files_list}` を取得する
2. `Bash` でコミットする:
   ```
   git add {files_list の各ファイル} && git commit -m "fix(#{issue_number}): address review findings"
   ```
3. `{review_loop}` += 1 とし、`.tasks/{issue_number}/state.md` に `review_loop: {review_loop}` を Edit で追記/更新する
4. ステップ1 に戻る（再レビュー）

---

### Phase 4: PR更新

#### ステップ1: Push

1. `Bash` で `git push` を実行する

#### ステップ1.5: 受け入れ基準検証（サブエージェントに委譲）

1. `Bash` で Issue 本文を取得する:
   ```
   gh issue view {issue_number} --json body --jq '.body'
   ```
2. diff ファイルが未取得の場合、`Bash` で取得する:
   ```
   git diff origin/{baseRefName}...HEAD > .tasks/{issue_number}/code-diff.txt
   ```
3. `Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

   `.claude/skills/issue_implement/templates/phase4-verify-acceptance.md` を Read で読み込み、その内容に従って処理を実行してください。
   パス変数:
   - `{issue_body}`: Issue本文
   - `{requirements_path}`: `.tasks/{issue_number}/requirements.md` の絶対パス
   - `{design_path}`: `.tasks/{issue_number}/design.md` の絶対パス
   - `{diff_path}`: `.tasks/{issue_number}/code-diff.txt` の絶対パス
   - `{verification_save_path}`: `.tasks/{issue_number}/acceptance-verification.md` の絶対パス

4. サブエージェントの返答に応じた処理:

   **result: pass の場合**:
   - 検証結果サマリをテキスト出力する
   - ステップ2 へ進む

   **result: needs_action の場合**:
   - 未充足基準の一覧をテキスト出力する
   - 「受け入れ基準の一部が未充足です。`.tasks/{issue_number}/acceptance-verification.md` を確認してください。設計の問題の場合は `/issue_design {issue_number}` で修正し、実装の問題の場合は手動修正後に `/issue_implement {issue_number}` を再実行してください」と出力し、スキル終了

#### ステップ2: PR Ready化

1. `Bash` で PR を Ready for Review にする:
   ```
   gh pr ready {pr_number}
   ```

#### ステップ3: PR description更新（サブエージェントに委譲）

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/issue_implement/templates/phase4-pr-update.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{design_path}`: `.tasks/{issue_number}/design.md` の絶対パス
- `{plan_path}`: `.tasks/{issue_number}/implementation-plan.md` の絶対パス
- `{consolidated_path}`: `.tasks/{issue_number}/code-review-consolidated.md` の絶対パス
- `{issue_number}`: Issue番号
- `{issue_title}`: Issueタイトル
- `{pr_body_save_path}`: `.tasks/{issue_number}/pr-update-body.md` の絶対パス

#### ステップ4: PR description 追記

1. `.tasks/{issue_number}/pr-update-body.md` を Read で読み込む
2. `Bash` で現在の PR body を取得する:
   ```
   gh pr view {pr_number} --json body --jq '.body'
   ```
3. 既存 body に実装サマリセクションを追記し、`.tasks/{issue_number}/pr-updated-body.md` に Write で保存する
4. `Bash` で PR description を更新する:
   ```
   gh pr edit {pr_number} --body-file .tasks/{issue_number}/pr-updated-body.md
   ```

#### ステップ5: レビュー依頼コメント

1. `.tasks/{issue_number}/pr-update-body.md` の「レビュー依頼」セクションを抽出し、`.tasks/{issue_number}/review-request.md` に Write で保存する
2. `Bash` で PR コメントとして投稿する:
   ```
   gh pr comment {pr_number} --body-file .tasks/{issue_number}/review-request.md
   ```

#### ステップ6: state.md 更新 + 完了出力

1. `.tasks/{issue_number}/state.md` を Edit で更新する: `phase: pr_ready`
2. 以下を出力してスキル終了:
   ```
   ## Phase 4 完了

   - PR: #{pr_number} (Ready for Review)
   - ブランチ: {branch}

   PR をレビューしてマージしてください。
   レビュー指摘がある場合は `/issue_implement {issue_number}` を再実行すると Phase 5 で自動対応します。
   ```

---

### Phase 5: PR指摘対応

#### ステップ1: PRコメント取得

1. state.md から `{pr_number}` を取得する
2. state.md の phase が `pr_ready` の場合、Edit で `phase: feedback_in_progress` に更新する
3. `Bash` でリポジトリ情報を取得する:
   ```
   gh repo view --json nameWithOwner --jq '.nameWithOwner'
   ```
4. `Bash` で PR コメントを取得する:
   ```
   gh pr view {pr_number} --json comments,reviews
   ```
5. `Bash` で review comments（行レベル）を取得する:
   ```
   gh api repos/{owner}/{repo}/pulls/{pr_number}/comments
   ```
6. `.tasks/{issue_number}/feedback-status.md` を Read で読み込む（存在しない場合は空として扱う）
7. feedback-status.md に記録済みの `comment_id` のリストを取得する
8. ステップ4・5 で取得したコメントから、記録済み comment_id に一致するものを除外する
   - 一般コメントの ID: `general-{ステップ4のJSONレスポンスの各コメントの id}`
   - レビューコメントの ID: `review-{ステップ5のJSONレスポンスの各コメントの id}`
9. 未処理のコメントのみを整形し、`.tasks/{issue_number}/pr-feedback.md` に Write で保存する:
   ```
   # PRフィードバック

   ## 一般コメント

   ### コメント 1
   - comment_id: general-{id}
   - 投稿者: {author}
   - 日時: {createdAt}
   - 内容: {body}

   ## レビューコメント

   ### コメント 1
   - comment_id: review-{id}
   - 投稿者: {author}
   - ファイル: {path}:{line}
   - 日時: {createdAt}
   - 内容: {body}
   ```
10. 未処理コメントが 0 件の場合:
    - feedback-status.md に記録済みコメントがある場合:
      - 「新しいフィードバックコメントがありません。全てのコメントは対応済みです」と出力する
    - feedback-status.md に記録済みコメントがない場合:
      - 「PR上にフィードバックコメントがありません」と出力する
    - state.md を Edit で `phase: pr_ready` に戻す
    - スキル終了

#### ステップ2: コード修正（サブエージェントに委譲）

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/issue_implement/templates/phase5-address-feedback.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{design_path}`: `.tasks/{issue_number}/design.md` の絶対パス
- `{plan_path}`: `.tasks/{issue_number}/implementation-plan.md` の絶対パス
- `{feedback_path}`: `.tasks/{issue_number}/pr-feedback.md` の絶対パス
- `{reply_save_path}`: `.tasks/{issue_number}/feedback-reply.md` の絶対パス
- `{error_context}`: なし

サブエージェントの返答: `result` + `code_fixed` + `clarified` + `no_action` + `summary`

`{code_fixed}` が 0 の場合（コード修正なし）:
- ステップ5 へ進む（lint/test をスキップ）

`{retry_count}` = 0 とする。

#### ステップ3: lint/format + テスト

##### a. lint/format 実行

`{format_command}` と `{lint_command}` がともに「なし」の場合はスキップする。
- ツーリングコマンドは `.tasks/{issue_number}/implementation-plan.md` の「ツーリング」セクションから取得する

1. `{format_command}` が「なし」でない場合、`Bash` で実行する
2. `{lint_command}` が「なし」でない場合、`Bash` で実行する
3. 修正不能なエラーがある場合 → リトライ（下記 c.）

##### b. テスト実行

`{test_command}` が「なし」の場合はステップ4へ。

1. `Bash` で `{test_command}` を実行する
2. 成功 → ステップ4 へ
3. 失敗 → リトライ（下記 c.）

##### c. リトライ（上限2回）

`{retry_count}` が 2 未満の場合:
1. `{retry_count}` += 1
2. `Task` ツールで `templates/phase5-address-feedback.md` に委譲する（`{error_context}` に lint/test エラー出力を含める）
3. ステップ3 a.（lint/format）に戻る

`{retry_count}` が 2 以上の場合:
- 「PR指摘対応後のテスト/lint が通過しませんでした。詳細:\n{エラー出力}\n\n手動修正後に `/issue_implement {issue_number}` を再実行してください」と出力し、スキル終了

#### ステップ4: コミット + Push

1. サブエージェントの返答から `{files_list}` を取得する
2. `Bash` でコミットする:
   ```
   git add {files_list の各ファイル} && git commit -m "fix(#{issue_number}): address PR feedback"
   ```
3. `Bash` でプッシュする:
   ```
   git push
   ```

#### ステップ5: PR返信

1. `.tasks/{issue_number}/feedback-reply.md` を Read で読み込む
2. feedback-reply.md の内容をベースに `.tasks/{issue_number}/pr-reply.md` に整形して Write で保存する
3. 対応サマリを PR コメントとして投稿する:
   ```
   gh pr comment {pr_number} --body-file .tasks/{issue_number}/pr-reply.md
   ```
4. 投稿した返信コメントの ID を取得する:
   - `gh pr view {pr_number} --json comments --jq '.comments[-1].id'` で直近コメントの ID を取得する
   - `general-{id}` を `{reply_comment_id}` として保持する
5. `.tasks/{issue_number}/pr-feedback.md` から各コメントの `comment_id` を抽出する
6. `.tasks/{issue_number}/feedback-reply.md` から各コメントの対応ステータスを抽出する（code_fixed / clarified / no_action）
7. `.tasks/{issue_number}/feedback-status.md` を Read で読み込む（存在しない場合は新規作成）
8. 新しく処理したコメントのエントリと返信コメントのエントリを追記し、Write で保存する:
   ```
   # フィードバック対応状況

   | comment_id | type | status | round | summary |
   |-----------|------|--------|-------|---------|
   | {既存エントリをそのまま保持} |
   | {新規: comment_id, general/review, code_fixed/clarified/no_action, ラウンド番号, 対応サマリ} |
   | {reply_comment_id} | general | self_reply | {ラウンド番号} | 自動返信 |
   ```
   - `round` は feedback-status.md 内の既存最大 round + 1（初回は 1）
   - `type` は comment_id のプレフィックス（general / review）から判定

#### ステップ6: state.md 更新 + 完了出力

1. `.tasks/{issue_number}/state.md` を Edit で更新する: `phase: pr_ready`
2. 以下を出力してスキル終了:
   ```
   ## Phase 5 完了

   - コード修正: {code_fixed}件, 説明: {clarified}件, 対応不要: {no_action}件
   - {summary}

   PR を再確認してください。
   追加の指摘がある場合は `/issue_implement {issue_number}` を再実行してください。
   承認後はマージしてください。
   ```
