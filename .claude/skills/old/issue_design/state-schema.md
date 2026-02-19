# state.md スキーマ

`.tasks/{issue_number}/state.md` のフィールド定義。issue_design と issue_implement の両スキルが参照する。

## フィールド一覧

| フィールド | 型 | 書き込み元 | 読み取り元 | 説明 |
|-----------|-----|-----------|-----------|------|
| `phase` | string | 両スキル（各Phase） | 両スキル（Phase 0） | 現在のフェーズ。下記「phase 値と遷移」参照 |
| `pr_number` | integer | issue_design Phase 4 | issue_implement Phase 0 | Draft PR の番号 |
| `branch` | string | issue_design Phase 4 | issue_implement Phase 0 | 作業ブランチ名（`feature/issue-{issue_number}`） |
| `completed_steps` | comma-separated integers | issue_implement Phase 2 | issue_implement Phase 0 | 完了済み実装ステップ番号（例: `1,2,3`） |

## phase 値と遷移

### issue_design が管理する phase

| phase 値 | 設定タイミング | 次の遷移先 |
|----------|--------------|-----------|
| `started` | Phase 0: 初回セットアップ | → `questions_posted` / `requirements_done` / `split_done` |
| `questions_posted` | Phase 1: Issueに質問投稿 | → `started`（回答後に再実行） |
| `split_done` | Phase 1: Issue分割完了 | 終端（各サブIssueで再実行） |
| `requirements_done` | Phase 1: 要件確認完了 | → `design_done` |
| `design_done` | Phase 2: 設計完了 | → `review_done` |
| `review_done` | Phase 3: 設計レビュー通過 | → `draft_pr_created` |
| `draft_pr_created` | Phase 4: Draft PR作成 | → `design_feedback` / → issue_implement へ |
| `design_feedback` | Phase 5: 設計指摘対応中 | → `draft_pr_created` |

### issue_implement が管理する phase

| phase 値 | 設定タイミング | 次の遷移先 |
|----------|--------------|-----------|
| `plan_done` | Phase 1: 実装計画完了 | → `implementation_done` |
| `implementation_done` | Phase 2: 全ステップ実装完了 | → `review_in_progress` |
| `review_in_progress` | Phase 3: 実装レビュー中 | → `pr_ready` / → `implementation_done`（修正後再レビュー） |
| `pr_ready` | Phase 4: PR Ready化完了 | → `feedback_in_progress` / 終端（マージ） |
| `feedback_in_progress` | Phase 5: PR指摘対応中 | → `pr_ready` |

## state.md の記述例

```
phase: draft_pr_created
pr_number: 42
branch: feature/issue-123
```

```
phase: plan_done
pr_number: 42
branch: feature/issue-123
completed_steps: 1,2
```
