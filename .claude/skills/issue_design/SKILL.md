---
allowed-tools: Bash, Glob, Grep, Read, Write, Edit, Task, AskUserQuestion
description: GitHub Issueを起点に要件確認・調査・設計・レビュー・Draft PR作成を行うスキル
---

GitHub Issueを起点に、要件確認・調査・ADR作成・設計・設計レビューを行い、Draft PRを作成します。

## 使い方

```
/issue_design 123
```

Issue番号を引数に指定。要件が不明確な場合はIssueに質問コメントを投稿してスキル終了。回答後に再実行。

## コンテキスト節約の原則

1. **参照ファイルは使用するPhaseでのみ読み込む**（先読みしない）
2. **大量コンテンツの生成はサブエージェントに委譲する**
3. **サブエージェントからの返答は最小限にする**（詳細はファイルに保存させる）
4. **親コンテキストには要約・メタデータのみ保持する**
5. **サブエージェント間のデータ受け渡しはファイル経由で行う**（親を中継しない）

## アーキテクチャ方針

- **テンプレート方式**: 各フェーズの詳細指示はtemplatesのmdファイルに外部化
- **ファイルベースのデータフロー**: フェーズ間は `.tasks/${issue_number}/` 内のファイル経由（親を中継しない）
- **PR中心のレビュー**: AskUserQuestionは要件確認（Phase 1）のみ使用。設計・ADRの確認はDraft PR上で行う
- **gh CLIは親が実行**: サブエージェントはファイル生成のみ担当
- **異常系**: 状況報告+次アクション明示でスキル終了

## ワークフロー

Phase 0 でIssue取得・レジューム判定を行い、適切なPhaseにルーティングする。Phase 1 で要件を構造化し、Phase 2 以降で調査・設計・レビュー・Draft PR作成を行う。

**v0.4**: Phase 0 〜 Phase 5 実装済み。

---

### Phase 0: Issue取得・レジューム判定

#### Issue番号の取得

1. 引数からIssue番号を取得する
   - 未指定の場合は `AskUserQuestion` で確認する

#### Issue情報の取得

2. `Bash` で以下を実行してIssue情報を取得する:
   ```
   gh issue view {issue_number} --json number,title,body,labels,comments,state
   ```
   - 取得失敗時: 「Issue #{issue_number} の取得に失敗しました。Issue番号を確認してください」と出力し、スキル終了

3. Issue情報から以下を保持する:
   - `{issue_title}`: タイトル
   - `{issue_body}`: 本文
   - `{issue_labels}`: ラベル（カンマ区切り）
   - `{issue_comments}`: コメント一覧（JSON文字列）

#### レジューム判定

4. `.tasks/{issue_number}/` ディレクトリの存在を Glob で確認する
5. `.tasks/{issue_number}/state.md` を Read で読み込む

#### state.md の phase によるルーティング

6. phase に応じて以下にルーティングする:

   | phase | ルーティング先 |
   |-------|-------------|
   | なし（ディレクトリなし / state.md なし） | 下記「初回セットアップ」→ Phase 1 |
   | `started` | Phase 1 ステップ1.75（受け入れ基準チェック）へ |
   | `ac_requested` | Phase 1 ステップ1.5（受け入れ基準確認）へ |
   | `split_done` | 「このIssueは分割済みです。各サブIssueに対して `/issue_design N` を実行してください」と出力し、スキル終了 |
   | `questions_posted` | Phase 1 ステップ1（回答確認）へ |
   | `requirements_done` | Phase 2 へ |
   | `design_done` | Phase 3 へ |
   | `review_done` | Phase 4 へ |
   | `draft_pr_created` / `design_feedback` | Phase 5 へ |

#### 初回セットアップ（state.md なしの場合）

7. `.tasks/{issue_number}/` ディレクトリを作成する（Bash: `mkdir -p .tasks/{issue_number}`）
8. `.tasks/{issue_number}/state.md` を Write で作成する:
   ```
   phase: started
   ```
9. Phase 1 ステップ1.75 へ進む

---

### Phase 1: 要件確認

#### ステップ1: 回答確認（phase: questions_posted からのレジューム時のみ）

1. Issue情報の `{issue_comments}` から、前回投稿した質問への回答を確認する
2. 回答が見つからない場合:
   - 「Issueへの質問に対する回答がまだ確認できません。回答後に `/issue_design {issue_number}` を再実行してください」と出力し、スキル終了
3. 回答が見つかった場合:
   - 回答内容を `{issue_comments}` に含めてステップ2へ進む

#### ステップ1.5: 受け入れ基準確認（phase: ac_requested からのレジューム時のみ）

1. `{issue_body}` と `{issue_comments}` を確認し、受け入れ基準が追記されたか確認する
   - 判定基準: 「受け入れ基準」「Acceptance Criteria」「完了条件」「Definition of Done」等のセクション見出し、またはチェックボックス形式の検証可能条件
2. 追記が確認できない場合:
   - 「Issueへの受け入れ基準の追記がまだ確認できません。追記後に `/issue_design {issue_number}` を再実行してください」と出力し、スキル終了
3. 追記が確認できた場合:
   - ステップ2 へ進む

#### ステップ1.75: 受け入れ基準チェック（phase: started の場合のみ）

1. `{issue_body}` と `{issue_comments}` を確認し、受け入れ基準に相当する記述があるか判定する
   - 判定基準: 「受け入れ基準」「Acceptance Criteria」「完了条件」「Definition of Done」等のセクション見出し、またはチェックボックス形式の検証可能条件
2. 存在する場合: ステップ2 へ進む
3. 存在しない場合:
   - `Bash` で Issue にコメントを投稿する:
     ```
     gh issue comment {issue_number} --body "## 受け入れ基準の追記をお願いします

     このIssueに受け入れ基準（Acceptance Criteria）が記載されていません。
     設計・実装の完了判定に必要なため、以下の形式で追記をお願いします:

     ### 受け入れ基準
     - [ ] {検証可能な条件1}
     - [ ] {検証可能な条件2}

     追記後に \`/issue_design {issue_number}\` を再実行してください。"
     ```
   - `.tasks/{issue_number}/state.md` を Edit で更新する: `phase: ac_requested`
   - 「Issue #{issue_number} に受け入れ基準の追記を依頼しました。追記後に `/issue_design {issue_number}` を再実行してください」と出力し、スキル終了

#### ステップ2: 要件構造化（サブエージェントに委譲）

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/issue_design/templates/phase1-requirements.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{issue_number}`: Issue番号
- `{issue_title}`: Issueタイトル
- `{issue_body}`: Issue本文
- `{issue_labels}`: Issueラベル（カンマ区切り）
- `{issue_comments}`: Issueコメント（JSON文字列）
- `{requirements_save_path}`: `.tasks/{issue_number}/requirements.md` の絶対パス
- `{modification_instructions}`: ユーザーからの修正指示（初回は「なし」）

サブエージェントの返答は以下のいずれか:
- **A) 要件不明確** — `result: unclear` + 質問リスト
- **B) 要件明確** — `result: clear` + サマリ + 規模見積もり

#### ステップ3: 不明確な場合の処理（返答がAの場合）

1. サブエージェントが返した質問リストを `Bash` で Issueコメントとして投稿する:
   ```
   gh issue comment {issue_number} --body "{questions_body}"
   ```
2. `.tasks/{issue_number}/state.md` を Edit で更新する: `phase: questions_posted`
3. 「Issue #{issue_number} に質問を投稿しました。回答後に `/issue_design {issue_number}` を再実行してください」と出力し、スキル終了

#### ステップ4: 明確な場合の処理（返答がBの場合）

1. サブエージェントが返した要件サマリと規模見積もりをユーザーにテキスト出力する
2. `AskUserQuestion` で方針を確認する:
   - 選択肢:
     - **続行** — この要件で進める
     - **分割** — Issueを複数のサブIssueに分割する
     - **修正指示** — 要件の修正点を指示する（自由記述）
   - 規模見積もりが XL の場合は「規模が大きいため分割を推奨します」を付記する

#### ステップ5: 分割の場合

1. `AskUserQuestion` でサブIssueのタイトルと概要案を提示し、分割方針を確認する
2. 各サブIssueを `Bash` で作成する:
   ```
   gh issue create --title "{title}" --body "{body}"
   ```
3. 元Issueに分割コメントを `Bash` で投稿する:
   ```
   gh issue comment {issue_number} --body "このIssueを以下のサブIssueに分割しました: ..."
   ```
4. `.tasks/{issue_number}/state.md` を Edit で更新する: `phase: split_done`
5. 「Issue #{issue_number} を分割しました。各サブIssueに対して `/issue_design N` を実行してください」と出力し、スキル終了
   - 補足: サブIssue間の依存関係（実行順序・ブランチ戦略・マージ順序）はユーザーが管理する。各サブIssueは独立して `/issue_design` → `/issue_implement` パイプラインを実行する

#### ステップ6: 続行の場合

1. `.tasks/{issue_number}/requirements.md` が保存されていることを Read で確認する
2. `.tasks/{issue_number}/state.md` を Edit で更新する: `phase: requirements_done`
3. 以下を出力する:
   ```
   ## Phase 1 完了

   - Issue: #{issue_number} {issue_title}
   - 要件: .tasks/{issue_number}/requirements.md

   Phase 2（調査・ADR・設計）に進みます。
   ```
4. Phase 2 へ進む

#### ステップ7: 修正指示の場合

1. ユーザーの修正指示を `{modification_instructions}` として保持する
2. ステップ2に戻り、サブエージェントに修正指示を追加パス変数として渡す

---

### Phase 2: 調査・ADR・設計

#### ステップ1: コードベース調査・ADRチェック・設計生成（サブエージェントに委譲）

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/issue_design/templates/phase2-design.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{issue_number}`: Issue番号
- `{issue_title}`: Issueタイトル
- `{issue_body}`: Issue本文
- `{requirements_path}`: `.tasks/{issue_number}/requirements.md` の絶対パス
- `{design_save_path}`: `.tasks/{issue_number}/design.md` の絶対パス
- `{adr_dir}`: `docs/adr/` の絶対パス

サブエージェントの返答は以下のいずれか:
- **A) 成功** — `result: success` + 設計サマリ
- **B) 技術的制約矛盾** — `result: constraint_conflict` + 矛盾の詳細
- **C) ADR矛盾** — `result: adr_conflict` + 矛盾の詳細

#### ステップ2: 結果に応じた処理

**A) 成功の場合**:
1. サブエージェントが返した設計サマリをユーザーにテキスト出力する
2. `.tasks/{issue_number}/design.md` が保存されていることを Read で確認する
3. `.tasks/{issue_number}/state.md` を Edit で更新する: `phase: design_done`
4. 以下を出力する:
   ```
   ## Phase 2 完了

   - 設計: .tasks/{issue_number}/design.md

   Phase 3（設計レビュー）に進みます。
   ```
5. Phase 3 へ進む

**B) 技術的制約矛盾の場合**:
1. 矛盾の詳細をユーザーにテキスト出力する
2. 「技術的制約に矛盾が検出されました。Issueでの仕様再検討をお願いします」と出力し、スキル終了

**C) ADR矛盾の場合**:
1. 矛盾するADRと設計要素の詳細をユーザーにテキスト出力する
2. 「既存ADRとの矛盾が検出されました。ADR更新または設計変更を検討してください」と出力し、スキル終了

---

### Phase 3: 設計レビュー

#### ステップ0: 準備

1. `.tasks/{issue_number}/state.md` から `review_loop` を読み取る（なければ 0）
2. `{review_loop}` として保持する

#### ステップ1: 並列レビュー実行

以下の5つを `Task` ツールで **1つのメッセージで並列に** 起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

| 観点 | agent定義 | 結果保存先 |
|------|----------|-----------|
| security | `agents/security-design-reviewer.md` | `.tasks/{issue_number}/design-review-security.md` |
| performance | `agents/performance-design-reviewer.md` | `.tasks/{issue_number}/design-review-performance.md` |
| consistency | `agents/consistency-design-reviewer.md` | `.tasks/{issue_number}/design-review-consistency.md` |
| maintainability | `agents/maintainability-design-reviewer.md` | `.tasks/{issue_number}/design-review-maintainability.md` |
| reliability | `agents/reliability-design-reviewer.md` | `.tasks/{issue_number}/design-review-reliability.md` |

各レビューアーへのプロンプト:

`.claude/skills/issue_design/templates/phase3-review.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{perspective}`: {観点名}
- `{agent_definition_path}`: `.claude/skills/issue_design/agents/{perspective}-design-reviewer.md` の絶対パス
- `{design_path}`: `.tasks/{issue_number}/design.md` の絶対パス
- `{requirements_path}`: `.tasks/{issue_number}/requirements.md` の絶対パス
- `{findings_save_path}`: `.tasks/{issue_number}/design-review-{perspective}.md` の絶対パス

5件全ての Task 完了後、各返答のサマリをテキスト出力する。

#### ステップ2: レビュー結果統合

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/issue_design/templates/phase3-consolidate-reviews.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{review_paths}`: `.tasks/{issue_number}/design-review-security.md`, `.tasks/{issue_number}/design-review-performance.md`, `.tasks/{issue_number}/design-review-consistency.md`, `.tasks/{issue_number}/design-review-maintainability.md`, `.tasks/{issue_number}/design-review-reliability.md` の絶対パスリスト
- `{consolidated_save_path}`: `.tasks/{issue_number}/design-review-consolidated.md` の絶対パス

サブエージェントの返答: `verdict` + `critical` + `significant` + `total` + `summary`

#### ステップ3: 結果に応じた処理

**verdict: pass の場合**:
1. レビュー結果サマリをユーザーにテキスト出力する
2. `.tasks/{issue_number}/state.md` を Edit で更新する: `phase: review_done`
3. Phase 4 へ進む

**verdict: needs_revision の場合**:
1. レビュー結果サマリ（Critical/Significant 指摘一覧）をユーザーにテキスト出力する
2. 現在のレビューループ回数が 2回目以上の場合:
   - 「設計レビューで重大な指摘が解消されませんでした。`.tasks/{issue_number}/design-review-consolidated.md` を確認し、設計を手動で修正してから `/issue_design {issue_number}` を再実行してください」と出力し、スキル終了
3. ステップ4 へ進む

#### ステップ4: 設計修正

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/issue_design/templates/phase3-fix-design.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{design_path}`: `.tasks/{issue_number}/design.md` の絶対パス
- `{consolidated_path}`: `.tasks/{issue_number}/design-review-consolidated.md` の絶対パス
- `{requirements_path}`: `.tasks/{issue_number}/requirements.md` の絶対パス

修正サマリをテキスト出力する。`{review_loop}` += 1 とし、`.tasks/{issue_number}/state.md` に `review_loop: {review_loop}` を Edit で追記/更新する。ステップ1 に戻る（再レビュー）。

---

### Phase 4: Draft PR作成

#### ステップ1: ブランチ作成

1. `Bash` で現在のブランチ名を確認する: `git branch --show-current`
2. `Bash` でブランチを作成・切替する:
   ```
   git checkout -b feature/issue-{issue_number}
   ```
   - ブランチが既に存在する場合: `git checkout feature/issue-{issue_number}`

#### ステップ2: .gitignore 確認

1. `.gitignore` を Read で確認し、`.tasks/*/state.md` が含まれているか確認する
2. 含まれていない場合、Edit で `.tasks/*/state.md` を追加する

#### ステップ3: コミット

1. `Bash` でファイルをステージする:
   ```
   git add .tasks/{issue_number}/requirements.md .tasks/{issue_number}/design.md
   ```
   - Step 2 で `.gitignore` を変更した場合はそれも追加する: `git add .gitignore`
   - `docs/adr/` に新規 ADR ファイルがある場合はそれも追加する: `git add docs/adr/`
2. `Bash` でコミットする:
   ```
   git commit -m "docs: add requirements and design for #{issue_number}"
   ```

#### ステップ4: Push + Draft PR作成

1. `Bash` でプッシュする:
   ```
   git push -u origin feature/issue-{issue_number}
   ```
2. PR body を `.tasks/{issue_number}/pr-body.md` に Write で保存する。内容には以下を含む:
   - Issue へのリンク（`Closes #{issue_number}`）
   - 設計サマリ（design.md の「概要」セクション）
   - レビュー結果サマリ
   - ADR リスト（あれば）
3. `Bash` で Draft PR を作成する:
   ```
   gh pr create --draft --title "#{issue_number} {issue_title}" --body-file .tasks/{issue_number}/pr-body.md
   ```

4. `gh pr create` の出力から PR 番号を取得する

#### ステップ5: state.md 更新

1. `.tasks/{issue_number}/state.md` を Write で更新する:
   ```
   phase: draft_pr_created
   pr_number: {PR番号}
   branch: feature/issue-{issue_number}
   ```
2. 以下を出力してスキル終了:
   ```
   ## Phase 4 完了

   - Draft PR: #{pr_number}
   - ブランチ: feature/issue-{issue_number}

   Draft PR 上で設計をレビューしてください。
   指摘がある場合は PR にコメントし、`/issue_design {issue_number}` を再実行すると Phase 5 で自動対応します。
   承認後は `/issue_implement {issue_number}` で実装に進めます。
   ```

---

### Phase 5: 設計指摘対応

#### ステップ1: PRコメント取得

1. state.md から `{pr_number}` を取得する
2. state.md の phase が `draft_pr_created` の場合、Edit で `phase: design_feedback` に更新する
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
      - 「PR上にフィードバックコメントがありません。Draft PR上でレビューコメントを追加してから再実行してください」と出力する
    - state.md を Edit で `phase: draft_pr_created` に戻す
    - スキル終了

#### ステップ2: 設計修正（サブエージェントに委譲）

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/issue_design/templates/phase5-address-feedback.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{requirements_path}`: `.tasks/{issue_number}/requirements.md` の絶対パス
- `{design_path}`: `.tasks/{issue_number}/design.md` の絶対パス
- `{feedback_path}`: `.tasks/{issue_number}/pr-feedback.md` の絶対パス
- `{reply_save_path}`: `.tasks/{issue_number}/feedback-reply.md` の絶対パス

サブエージェントの返答: `result` + `addressed` + `no_action` + `summary`

#### ステップ3: コミット + Push

1. `Bash` でファイルをステージする:
   ```
   git add .tasks/{issue_number}/design.md
   ```
   - `docs/adr/` に変更がある場合はそれも追加する: `git add docs/adr/`
2. `Bash` でコミットする:
   ```
   git commit -m "docs: address PR feedback for #{issue_number}"
   ```
   - 変更がない場合（全コメントが acknowledged）はコミットをスキップする
3. `Bash` でプッシュする:
   ```
   git push
   ```

#### ステップ4: PR返信

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
6. `.tasks/{issue_number}/feedback-reply.md` から各コメントの対応ステータスを抽出する（addressed / no_action）
7. `.tasks/{issue_number}/feedback-status.md` を Read で読み込む（存在しない場合は新規作成）
8. 新しく処理したコメントのエントリと返信コメントのエントリを追記し、Write で保存する:
   ```
   # フィードバック対応状況

   | comment_id | type | status | round | summary |
   |-----------|------|--------|-------|---------|
   | {既存エントリをそのまま保持} |
   | {新規: comment_id, general/review, addressed/no_action, ラウンド番号, 対応サマリ} |
   | {reply_comment_id} | general | self_reply | {ラウンド番号} | 自動返信 |
   ```
   - `round` は feedback-status.md 内の既存最大 round + 1（初回は 1）
   - `type` は comment_id のプレフィックス（general / review）から判定

#### ステップ5: state.md 更新 + 完了出力

1. `.tasks/{issue_number}/state.md` を Edit で更新する: `phase: draft_pr_created`
2. 以下を出力してスキル終了:
   ```
   ## Phase 5 完了

   - 対応: {addressed}件, 対応不要: {no_action}件
   - {summary}

   Draft PR を再確認してください。
   追加の指摘がある場合は PR にコメントし、`/issue_design {issue_number}` を再実行してください。
   承認後は `/issue_implement {issue_number}` で実装に進めます。
   ```
