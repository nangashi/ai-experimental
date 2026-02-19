# issue_design / issue_implement 開発パイプライン

GitHub Issueを起点に、設計から実装・マージまでの全工程をスキルで自動化するパイプライン。

## 全体パイプライン

```mermaid
flowchart TB
    Issue(["GitHub Issue #N"]) --> design_cmd(["/issue_design N"])
    design_cmd --> D_P0

    subgraph design ["issue_design"]
        direction TB
        D_P0["Phase 0\nIssue取得・レジューム判定"]
        D_P1["Phase 1\n要件確認・構造化"]
        D_P2["Phase 2\n調査・ADR・設計"]
        D_P3["Phase 3\n設計レビュー（自動4観点）"]
        D_P4["Phase 4\nDraft PR作成"]

        D_P0 --> D_P1
        D_P1 -- "requirements.md" --> D_P2
        D_P2 -- "design.md" --> D_P3
        D_P3 --> D_P4
    end

    D_P4 --> DraftPR(["Draft PR #M\n(requirements.md + design.md)"])

    DraftPR --> UserReview{"ユーザー\nDraft PRレビュー"}
    UserReview -->|指摘あり| D_P5

    subgraph design_fix ["issue_design（指摘対応）"]
        D_P5["Phase 5\n設計指摘対応・修正・返信"]
    end

    D_P5 --> UserReview
    UserReview -->|承認| impl_cmd(["/issue_implement N"])
    impl_cmd --> I_P0

    subgraph implement ["issue_implement"]
        direction TB
        I_P0["Phase 0\n設計読み取り・レジューム判定"]
        I_P1["Phase 1\n実装ステップ計画"]
        I_P2["Phase 2\nステップ実装 + lint/test"]
        I_P3["Phase 3\n実装レビュー（自動4観点）"]
        I_P4["Phase 4\nPR Ready化"]

        I_P0 --> I_P1
        I_P1 -- "implementation-plan.md" --> I_P2
        I_P2 --> I_P3
        I_P3 --> I_P4
    end

    I_P4 --> ReadyPR(["Ready PR #M\n(実装コード + テスト)"])

    ReadyPR --> ReviewerReview{"レビュアー\nPRレビュー"}
    ReviewerReview -->|指摘あり| I_P5

    subgraph impl_fix ["issue_implement（指摘対応）"]
        I_P5["Phase 5\nPR指摘対応・修正・返信"]
    end

    I_P5 --> ReviewerReview
    ReviewerReview -->|承認| Merge(["マージ"])
```

## 状態遷移図（state.md）

両スキルは `.tasks/N/state.md` の `phase` フィールドで進捗を管理し、中断・再開（レジューム）を実現する。

```mermaid
stateDiagram-v2
    direction TB

    state "issue_design" as design {
        [*] --> started: 初回実行\nmkdir + state.md作成

        started --> questions_posted: 要件不明確\nIssueに質問投稿
        questions_posted --> started: 回答確認後\n再構造化

        started --> split_done: Issue分割
        split_done --> [*]: 各サブIssueで\n/issue_design N

        started --> requirements_done: 要件確認完了\nrequirements.md保存

        requirements_done --> design_done: 調査・設計完了\ndesign.md保存

        design_done --> review_done: 設計レビュー通過

        review_done --> draft_pr_created: Draft PR作成\npr_number + branch記録

        draft_pr_created --> design_feedback: ユーザー指摘あり
        design_feedback --> draft_pr_created: 指摘対応完了
    }

    state "issue_implement" as impl {
        draft_pr_created --> plan_done: 実装計画完了\nimplementation\nplan.md保存

        plan_done --> implementation_done: 全ステップ実装完了\ngit push

        implementation_done --> review_in_progress: 実装レビュー開始
        review_in_progress --> implementation_done: レビュー修正\n再レビュー

        review_in_progress --> pr_ready: レビュー通過\ngh pr ready

        pr_ready --> feedback_in_progress: レビュアー指摘あり
        feedback_in_progress --> pr_ready: 指摘対応完了

        pr_ready --> [*]: マージ
    }
```

## データフロー（.tasks/N/）

```mermaid
flowchart LR
    subgraph github ["GitHub"]
        Issue["Issue #N"]
        PR["PR #M"]
        IssueComment["Issueコメント\n(質問/分割通知)"]
        PRComment["PRコメント\n(レビュー依頼/指摘返信)"]
    end

    subgraph task_dir [".tasks/N/"]
        state["state.md\n(phase, pr_number, branch,\ncompleted_steps)"]
        req["requirements.md\n(要件定義)"]
        design_doc["design.md\n(設計ドキュメント)"]
        plan["implementation-plan.md\n(実装ステップ計画)"]
    end

    subgraph design_skill ["issue_design"]
        D1["Phase 1: 要件確認"]
        D2["Phase 2: 調査・設計"]
        D3["Phase 3: 設計レビュー"]
        D4["Phase 4: Draft PR"]
        D5["Phase 5: 指摘対応"]
    end

    subgraph impl_skill ["issue_implement"]
        I1["Phase 1: 計画"]
        I2["Phase 2: 実装"]
        I3["Phase 3: レビュー"]
        I4["Phase 4: PR更新"]
        I5["Phase 5: 指摘対応"]
    end

    Issue -->|読み取り| D1
    D1 -->|作成| req
    D1 -.->|不明確時| IssueComment

    req -->|入力| D2
    D2 -->|作成| design_doc

    design_doc -->|入力| D3
    D3 --> D4
    D4 -->|作成| PR

    PR -->|指摘読み取り| D5
    D5 -->|修正push| PR

    design_doc -->|入力| I1
    I1 -->|作成| plan

    plan -->|入力| I2
    I2 --> I3
    I3 --> I4
    I4 -->|Ready化| PR
    I4 -.-> PRComment

    PR -->|指摘読み取り| I5
    I5 -->|修正push + 返信| PR

    D1 -.->|更新| state
    D2 -.->|更新| state
    D3 -.->|更新| state
    D4 -.->|更新| state
    D5 -.->|更新| state
    I1 -.->|更新| state
    I2 -.->|更新| state
    I3 -.->|更新| state
    I4 -.->|更新| state
    I5 -.->|更新| state
```

## issue_design 詳細フロー

```mermaid
flowchart TD
    Start(["/issue_design N"]) --> P0_arg{引数に\nIssue番号あり?}
    P0_arg -->|なし| P0_ask["AskUserQuestion\nIssue番号を確認"]
    P0_ask --> P0_fetch
    P0_arg -->|あり| P0_fetch

    subgraph P0["Phase 0: Issue取得・レジューム判定"]
        P0_fetch["gh issue view N\n--json number,title,body,\nlabels,comments,state"]
        P0_fetch --> P0_ok{取得成功?}
        P0_ok -->|失敗| P0_err(["エラー終了\nIssue番号を確認"])
        P0_ok -->|成功| P0_dir{".tasks/N/\n存在?"}
        P0_dir -->|なし| P0_init["mkdir -p .tasks/N/\nstate.md作成\n(phase: started)"]
        P0_init --> P1_s2
        P0_dir -->|あり| P0_state["state.md 読み込み"]
        P0_state --> P0_phase{phase?}
        P0_phase -->|started| P1_s2
        P0_phase -->|questions_posted| P1_s1
        P0_phase -->|split_done| P0_split(["終了: 分割済み\n各サブIssueで\n/issue_design N"])
        P0_phase -->|requirements_done| P0_to_p2(["Phase 2へ\n(v0.2以降)"])
        P0_phase -->|design_done| P0_to_p3(["Phase 3へ\n(v0.3以降)"])
        P0_phase -->|review_done| P0_to_p4(["Phase 4へ\n(v0.3以降)"])
        P0_phase -->|draft_pr_created\n/ design_feedback| P0_to_p5(["Phase 5へ\n(v0.4以降)"])
    end

    subgraph P1["Phase 1: 要件確認"]
        P1_s1["Step 1: Issueコメントから\n前回質問への回答を確認"]
        P1_s1 --> P1_ans{回答あり?}
        P1_ans -->|なし| P1_wait(["終了: 回答待ち\n回答後に再実行"])
        P1_ans -->|あり| P1_s2

        P1_s2["Step 2: サブエージェント（sonnet）\n5観点で要件を分析・構造化\n目的 / 背景 / 機能要件 /\n非機能要件 / スコープ"]
        P1_s2 --> P1_judge{判定結果}

        P1_judge -->|unclear| P1_s3["Step 3:\ngh issue comment N\nで質問を投稿\nstate.md → questions_posted"]
        P1_s3 --> P1_q_exit(["終了: 質問投稿済み\n回答後に再実行"])

        P1_judge -->|clear| P1_s4["Step 4:\n要件サマリ + 規模見積もり\n(S: 1-2files / M: 3-5files /\nL: 6-10files / XL: 11+files)\nAskUserQuestionで方針確認"]
        P1_s4 --> P1_choice{ユーザー選択}

        P1_choice -->|続行| P1_s6["Step 6:\nrequirements.md 確認\nstate.md → requirements_done"]
        P1_s6 --> P1_done(["Phase 1 完了"])

        P1_choice -->|分割| P1_s5["Step 5:\nAskUserQuestionで分割案確認\ngh issue create x N\n元Issueに分割コメント投稿\nstate.md → split_done"]
        P1_s5 --> P1_split(["終了: 分割完了\n各サブIssueで\n/issue_design N"])

        P1_choice -->|修正指示| P1_s7["Step 7:\n修正指示を保持"]
        P1_s7 --> P1_s2
    end

    subgraph P2["Phase 2: 調査・ADR・設計（v0.2 予定）"]
        P2_1["コードベース調査\n影響範囲・既存パターン分析"]
        P2_2["ADRチェック\n関連する既存ADR確認\n必要に応じて新規ADR作成"]
        P2_3["設計ドキュメント生成\n.tasks/N/design.md"]
        P2_4["state.md → design_done"]
        P2_1 --> P2_2 --> P2_3 --> P2_4
    end

    P1_done --> P2

    subgraph P3["Phase 3: 設計レビュー（v0.3 予定）"]
        P3_1["設計レビューエージェント並列実行"]
        P3_sec["security\n脅威モデリング\n認証・認可設計\nデータ保護"]
        P3_perf["performance\nアルゴリズム効率\nI/Oパターン\nスケーラビリティ"]
        P3_cons["consistency\n既存パターン整合\n命名規約\nAPI設計"]
        P3_maint["maintainability\n変更容易性\n結合度/凝集度\nテスト容易性"]
        P3_1 --> P3_sec & P3_perf & P3_cons & P3_maint
        P3_sec & P3_perf & P3_cons & P3_maint --> P3_merge["レビュー結果統合"]
        P3_merge --> P3_check{重大指摘あり?}
        P3_check -->|あり| P3_fix["設計修正"]
        P3_fix --> P3_1
        P3_check -->|なし| P3_done["state.md → review_done"]
    end

    P2_4 --> P3

    subgraph P4["Phase 4: Draft PR作成（v0.3 予定）"]
        P4_1["ブランチ作成\n(feature/issue-N)"]
        P4_2["requirements.md +\ndesign.md をコミット"]
        P4_3["gh pr create --draft\nPR descriptionに設計サマリ"]
        P4_4["state.md 更新\nphase: draft_pr_created\npr_number: M\nbranch: feature/issue-N"]
        P4_1 --> P4_2 --> P4_3 --> P4_4
    end

    P3_done --> P4
    P4_4 --> P4_exit(["Draft PR作成完了\nユーザーがDraft PRをレビュー"])

    subgraph P5["Phase 5: 設計指摘対応（v0.4 予定）"]
        P5_1["PRから未対応コメント取得"]
        P5_2["指摘分析・設計修正"]
        P5_3["修正をコミット + git push"]
        P5_4["PRコメントに返信"]
        P5_5["state.md → draft_pr_created"]
        P5_1 --> P5_2 --> P5_3 --> P5_4 --> P5_5
    end

    P5_5 --> P5_exit(["指摘対応完了\nユーザーが再レビュー"])

    style P2 stroke-dasharray: 5 5
    style P3 stroke-dasharray: 5 5
    style P4 stroke-dasharray: 5 5
    style P5 stroke-dasharray: 5 5
```

## issue_implement 詳細フロー

```mermaid
flowchart TD
    Start(["/issue_implement N"]) --> IP0_arg{引数に\nIssue番号あり?}
    IP0_arg -->|なし| IP0_ask["AskUserQuestion\nIssue番号を確認"]
    IP0_ask --> IP0
    IP0_arg -->|あり| IP0

    subgraph IP0["Phase 0: 設計読み取り・レジューム判定"]
        IP0_1[".tasks/N/state.md を読み取り"]
        IP0_2{state.mdに\npr_number あり?}
        IP0_1 --> IP0_2
        IP0_2 -->|なし| IP0_err(["エラー: issue_designが未完了\n/issue_design N を先に実行"])
        IP0_2 -->|あり| IP0_3["gh pr view でPR情報取得\nブランチをcheckout"]
        IP0_3 --> IP0_conflict["ベースブランチとの\nコンフリクトチェック"]
        IP0_conflict --> IP0_conflict_check{コンフリクト\nあり?}
        IP0_conflict_check -->|あり| IP0_conflict_err(["コンフリクトの詳細をログ出力\n手動でrebase/merge解決後に再実行"])
        IP0_conflict_check -->|なし| IP0_4[".tasks/N/design.md を読み取り"]
        IP0_4 --> IP0_5{design.md\n存在?}
        IP0_5 -->|なし| IP0_err2(["エラー: design.mdがありません\n/issue_design N を再実行"])
        IP0_5 -->|あり| IP0_6{state.mdの\nphase?}
        IP0_6 -->|draft_pr_created| IP0_out["Phase 1へ"]
        IP0_6 -->|plan_done| IP0_resume_check{completed_steps\nあり?}
        IP0_resume_check -->|なし| IP0_resume["Phase 2 Step 1から"]
        IP0_resume_check -->|あり| IP0_resume_ask["AskUserQuestionで\n次ステップの修正状況を確認"]
        IP0_resume_ask --> IP0_resume_r{修正済み?}
        IP0_resume_r -->|はい| IP0_resume_skip["completed_stepsに追加\n次ステップからPhase 2へ"]
        IP0_resume_r -->|いいえ| IP0_resume_retry["当該ステップから\nPhase 2へ"]
        IP0_6 -->|implementation_done\n/ review_in_progress| IP0_review["Phase 3へ"]
        IP0_6 -->|pr_ready\n/ feedback_in_progress| IP0_pr["PR未対応コメント\nを取得"]
        IP0_pr --> IP0_pr_check{未対応\n指摘あり?}
        IP0_pr_check -->|あり| IP0_feedback["Phase 5へ"]
        IP0_pr_check -->|なし| IP0_done(["完了\n次: PR #N をマージ"])
    end

    IP0_out --> IP1
    IP0_resume --> IP2
    IP0_resume_skip --> IP2
    IP0_resume_retry --> IP2
    IP0_review --> IP3
    IP0_feedback --> IP5

    subgraph IP1["Phase 1: 実装ステップ計画"]
        IP1_1["design.mdから\n実装ステップを抽出"]
        IP1_2["ステップごとの\n変更ファイル・依存関係を整理"]
        IP1_3[".tasks/N/implementation-plan.md\n生成"]
        IP1_4["state.md更新\n(phase: plan_done)"]
        IP1_1 --> IP1_2 --> IP1_3 --> IP1_4
    end

    IP1_4 --> IP2

    subgraph IP2["Phase 2: 実装"]
        IP2_1["Step N: サブエージェントに\n実装を委譲"]
        IP2_1a["親がlint/format実行\n(auto-fix適用)"]
        IP2_1b{lint/format\n通過?}
        IP2_1 --> IP2_1a --> IP2_1b
        IP2_1b -->|修正不能エラー| IP2_lint_cnt{リトライ\n上限(2回)?}
        IP2_lint_cnt -->|上限内| IP2_4["失敗情報を渡して\nサブエージェントで修正"]
        IP2_lint_cnt -->|超過| IP2_exit
        IP2_1b -->|通過| IP2_2["親がテスト実行\n(既存+新規)"]
        IP2_2 --> IP2_3{テスト通過?}
        IP2_3 -->|失敗| IP2_design{設計自体の\n問題?}
        IP2_design -->|はい| IP2_design_exit
        IP2_design -->|いいえ| IP2_test_cnt{リトライ\n上限(2回)?}
        IP2_test_cnt -->|上限内| IP2_4
        IP2_4 --> IP2_1a
        IP2_test_cnt -->|超過| IP2_exit
        IP2_3 -->|成功| IP2_5["コミット"]
        IP2_5 --> IP2_5a["state.md更新\n(completed_steps に追加)"]
        IP2_5a --> IP2_6{次ステップ\nあり?}
        IP2_6 -->|あり| IP2_1
        IP2_6 -->|なし| IP2_7["git push"]
        IP2_7 --> IP2_8["state.md更新\n(phase: implementation_done)"]
        IP2_8 --> IP2_out["全ステップ完了"]
    end

    IP2_design_exit(["終了: 設計の問題点をログ出力\n/issue_design N で設計修正後に再実行"])
    IP2_exit(["終了: テスト失敗の詳細をログ出力\n手動修正後に /issue_implement N で再実行"])

    IP2_out --> IP3

    subgraph IP3["Phase 3: 実装レビュー"]
        IP3_0["state.md更新\n(phase: review_in_progress)"]
        IP3_0 --> IP3_1
        IP3_1["実装レビューエージェント\nを並列実行\n(品質/テスト/セキュリティ/設計適合)"]
        IP3_2["レビュー結果を統合"]
        IP3_3{重大な指摘\nあり?}
        IP3_1 --> IP3_2 --> IP3_3
        IP3_3 -->|あり| IP3_design{設計自体の\n問題?}
        IP3_design -->|はい| IP3_design_exit
        IP3_design -->|いいえ| IP3_cnt{ループ\n上限(3回)?}
        IP3_cnt -->|上限内| IP3_4["実装を修正"]
        IP3_4 --> IP3_lint["lint/format実行"]
        IP3_lint --> IP3_test["テスト実行"]
        IP3_test --> IP3_test_ok{通過?}
        IP3_test_ok -->|失敗| IP3_test_cnt{リトライ\n上限(2回)?}
        IP3_test_cnt -->|上限内| IP3_4
        IP3_test_cnt -->|超過| IP3_exit
        IP3_test_ok -->|成功| IP3_commit["コミット"]
        IP3_commit --> IP3_1
        IP3_cnt -->|超過| IP3_exit
        IP3_3 -->|なし| IP3_out["レビュー完了"]
    end

    IP3_design_exit(["終了: 設計の問題点をログ出力\n/issue_design N で設計修正後に再実行"])
    IP3_exit(["終了: レビュー指摘/テスト失敗の\n詳細をログ出力\n手動修正後に再実行"])

    IP3_out --> IP4

    subgraph IP4["Phase 4: PR更新"]
        IP4_1["git push"]
        IP4_2["gh pr ready\n(Ready for Reviewに変更)"]
        IP4_3["PR descriptionに\n実装セクションを追記\n(変更ファイル概要/設計差分/\nレビューガイド)"]
        IP4_4["PRコメントに\nレビュー依頼を投稿\n(注目ポイント/変更規模/確認済み事項)"]
        IP4_5["state.md更新\n(phase: pr_ready)"]
        IP4_1 --> IP4_2 --> IP4_3 --> IP4_4 --> IP4_5
    end

    IP4 --> IP4_end(["終了: PR #M をレビューしてマージ"])

    subgraph IP5["Phase 5: PR指摘対応"]
        IP5_0["state.md更新\n(phase: feedback_in_progress)"]
        IP5_1["全未対応コメントを\n一括分析"]
        IP5_2["各指摘の要否を判断\n+ 修正計画を作成"]
        IP5_3["修正不要分:\nPRコメントに理由を返信"]
        IP5_4{修正要の\n指摘あり?}
        IP5_0 --> IP5_1 --> IP5_2 --> IP5_3 --> IP5_4
        IP5_4 -->|なし| IP5_done["state.md更新\n(phase: pr_ready)"]
        IP5_4 -->|あり| IP5_5["修正を一括実装"]
        IP5_5 --> IP5_5a["lint/format実行"]
        IP5_5a --> IP5_6["テスト実行"]
        IP5_6 --> IP5_7{テスト\n通過?}
        IP5_7 -->|失敗| IP5_cnt{リトライ\n上限(2回)?}
        IP5_cnt -->|上限内| IP5_8["失敗情報をもとに再修正"]
        IP5_8 --> IP5_6
        IP5_cnt -->|超過| IP5_exit
        IP5_7 -->|成功| IP5_9["コミット + git push"]
        IP5_9 --> IP5_10["PRコメントに\n修正内容を返信"]
        IP5_10 --> IP5_done
    end

    IP5_exit(["終了: テスト失敗の詳細をログ出力\n手動修正後に /issue_implement N で再実行"])
    IP5_done --> IP5_end(["終了: PR #M をレビューしてマージ\nまたは追加指摘後に再実行"])
```

## 異常系まとめ

```mermaid
flowchart LR
    subgraph errors ["異常系 → スキル終了 → ユーザーアクション → 再実行"]
        direction TB

        E1["Issue取得失敗"] -->|ユーザー| E1a["Issue番号を確認"]
        E1a --> E1b(["/issue_design N"])

        E2["要件不明確"] -->|スキル| E2a["Issueに質問投稿"]
        E2a -->|ユーザー| E2b["Issueに回答"]
        E2b --> E2c(["/issue_design N"])

        E3["設計の問題検出\n（実装/レビュー中）"] -->|ユーザー| E3a["設計を修正"]
        E3a --> E3b(["/issue_design N"])
        E3b --> E3c(["/issue_implement N"])

        E4["テスト失敗\n（リトライ上限超過）"] -->|ユーザー| E4a["手動でコード修正"]
        E4a --> E4b(["/issue_implement N\nAskUserQuestionで\n修正状況を確認"])

        E5["コンフリクト検出"] -->|ユーザー| E5a["手動でrebase/merge"]
        E5a --> E5b(["/issue_implement N"])

        E6["レビューループ上限超過"] -->|ユーザー| E6a["手動で指摘を解消"]
        E6a --> E6b(["/issue_implement N"])
    end
```

## 使い方

```
/issue_design 123      # Issue → 要件確認 → 設計 → Draft PR
/issue_implement 123   # 設計 → 実装 → レビュー → Ready PR
```

## 作業ディレクトリ（.tasks/N/）

| ファイル | 作成者 | 用途 |
|----------|--------|------|
| `state.md` | 両スキル | フェーズ進捗・PR番号・ブランチ名・completed_steps |
| `requirements.md` | issue_design Phase 1 | 要件定義（PRにコミット） |
| `design.md` | issue_design Phase 2 | 設計ドキュメント（PRにコミット） |
| `implementation-plan.md` | issue_implement Phase 1 | 実装ステップ計画 |

- `state.md` は `.gitignore` で除外（ローカル作業用）
- その他のファイルはブランチにコミットしてPR上でレビュー可能にする

## 段階的開発計画

| バージョン | issue_design | issue_implement |
|-----------|--------------|-----------------|
| v0.1 | Phase 0 + Phase 1（実装済み） | - |
| v0.2 | Phase 2 追加 | Phase 0 + Phase 1 + Phase 2 |
| v0.3 | Phase 3 + Phase 4 追加 | Phase 3 + Phase 4 追加 |
| v0.4 | Phase 5 追加 | Phase 5 追加 |
