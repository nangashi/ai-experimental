---
allowed-tools: Bash, Glob, Grep, Read, Write, Edit, Task, AskUserQuestion
description: スキルを多角的に批判レビューし、コンフリクト解決を経て改善・検証するスキル
---

指定されたスキルを5つの品質観点（安定性・効率性・UX・アーキテクチャ・有効性）で並列レビューし、コンフリクト解決を経て改善を適用します。

## 使い方

```
/skill_audit <skill_path> [force]
```

- `skill_path`: スキルディレクトリの絶対パスまたは相対パス（SKILL.md を含むディレクトリ）
- `force`（省略可能）: 全確認を自動判定で通過する。指摘は全件承認、失敗時は1回自動リトライ後中止。

未指定の場合は `AskUserQuestion` で確認してください。

## コンテキスト節約の原則

1. **大量コンテンツの生成・分析はサブエージェントに委譲する**
2. **サブエージェントからの返答は最小限にする**（詳細はファイルに保存させる）
3. **親コンテキストには要約・メタデータのみ保持する**

## ワークフロー

Phase 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 を順に実行します。

---

### Phase 0: 初期化・スキル検出

テキスト出力: `## Phase 0: 初期化・スキル検出`

1. 引数から `{skill_path}` を取得する（未指定の場合は `AskUserQuestion` で確認）
2. 第二引数が `force` かどうかを判定し `{force_mode}` フラグ（true/false）を設定する
3. `{skill_path}` を絶対パスに変換する
4. Read で `{skill_path}/SKILL.md` の存在を確認する。不在の場合はエラー出力して終了:
   「SKILL.md が見つかりません: {skill_path}/SKILL.md. スキルディレクトリを確認してください。」
5. Glob で `{skill_path}/**/*.md` を実行し `{file_list}` を構成する
6. `{skill_name}` = `{skill_path}` の末尾ディレクトリ名
7. `{timestamp}` = `date +%Y%m%d-%H%M%S` の出力（Bash）
8. `{work_dir}` = `.skill_audit/{skill_name}/run-{timestamp}`
9. `{skill_audit_path}` = `.claude/skills/skill_audit` の絶対パス（テンプレート参照用）
10. `mkdir -p {work_dir}` を実行する（Bash）
11. `{resolved_issues_path}` = `.skill_audit/{skill_name}/resolved-issues.md` の絶対パス
12. `{resolved_issues_path}` が存在しない場合: 以下の内容で Write して空ファイルを作成する:
    ```
    # Resolved Issues: {skill_name}
    ```
    存在する場合: テキスト出力: 「resolved-issues.md を検出。レビューアーに既知の解決済み指摘として提供します」
13. 自己改善検出: `{skill_name}` が `skill_audit` と一致する場合は警告出力:
    「注意: このスキル自身を改善対象としています。変更は次回の実行から反映されます。改善完了後、新しいターミナルセッションでスキルを再実行して変更を確認してください。」
14. `{force_mode}` が true の場合はテキスト出力: `force モード: 全確認を自動判定で通過します`

---

### Phase 1: スキル構造分析（サブエージェントに委譲）

テキスト出力: `## Phase 1: スキル構造分析`

テキスト出力の前に: Write で `{work_dir}/file-list.txt` に `{file_list}` を保存する（改行区切り）

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`{skill_audit_path}/agents/skill-structure-analyzer.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{skill_path}`: スキルディレクトリの絶対パス
- `{skill_name}`: スキル名
- `{file_list_path}`: {work_dir}/file-list.txt の絶対パス
- `{analysis_save_path}`: `{work_dir}/analysis.md` の絶対パス

サブエージェント完了後、返答内容（サマリ）をテキスト出力する。Task が失敗した場合: `{force_mode}` が true なら自動で1回リトライし、再失敗時は中止する。`{force_mode}` が false なら AskUserQuestion で「Phase 1 が失敗しました: {エラー内容}。リトライしますか？」と確認し、「リトライ」/「中止」の選択肢を提供する。

---

### Phase 2: 並列サブエージェントレビュー

テキスト出力:
```
## Phase 2: 多角的並列レビュー
- レビュータスク: 5件
- レビューアー: stability, efficiency, ux, architecture, effectiveness
- 対象スキル: {skill_name}
```

以下の5つを `Task` ツールで**1つのメッセージで並列に**起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

| エージェント | 結果保存先 |
|-------------|-----------|
| `agents/stability-reviewer.md` | `{work_dir}/review-stability.md` |
| `agents/efficiency-reviewer.md` | `{work_dir}/review-efficiency.md` |
| `agents/ux-reviewer.md` | `{work_dir}/review-ux.md` |
| `agents/architecture-reviewer.md` | `{work_dir}/review-architecture.md` |
| `agents/effectiveness-reviewer.md` | `{work_dir}/review-effectiveness.md` |

各レビューアーへのプロンプト:
```
`{skill_audit_path}/agents/{perspective}-reviewer.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- {skill_path}: {値}
- {analysis_path}: {work_dir}/analysis.md の絶対パス
- {quality_criteria_path}: {skill_audit_path}/quality-criteria.md の絶対パス
- {resolved_issues_path}: {resolved_issues_path} の値
- {findings_save_path}: {work_dir}/review-{perspective}.md の絶対パス
- {skill_name}: {値}
```

5件全ての Task 完了後、テキスト出力:
```
レビュー完了: {成功数}/5件
```

成功数が5未満の場合:
- 失敗したレビューアー名と失敗理由をテキスト出力する（Taskツールのエラー内容を含める）
- `{force_mode}` が true の場合: 成功数が3件以上なら自動続行し「force モード: {成功数}/5件で自動続行」とテキスト出力する。2件以下なら「force モード: 成功数が不足（{成功数}/5件）のため中止」とテキスト出力し終了する
- `{force_mode}` が false の場合: AskUserQuestion で「レビューが{成功数}/5件のみ完了しました（失敗: {失敗レビューアー名とエラー内容}）。続行しますか？」と確認し、「続行」/「中止」の選択肢を提供する

---

### Phase 3: フィードバック統合・コンフリクト解決

テキスト出力: `## Phase 3: フィードバック統合・コンフリクト解決`

#### Step 1: レビュー結果統合（サブエージェントに委譲）

`Task`（sonnet）で `{skill_audit_path}/templates/consolidate-reviews.md` に委譲する。パス変数:
- `{work_dir}`, `{skill_name}`, `{findings_save_path}`: `{work_dir}/findings.md`, `{conflicts_save_path}`: `{work_dir}/conflicts.md`

サブエージェント完了後、返答サマリ（critical, improvement, positive, conflicts, merged, filtered, truncated）をテキスト出力する。`filtered` > 0 の場合は「関連性フィルタで {filtered} 件除外（動作安定・性能に直結しない指摘）」を追記する。`truncated` > 0 の場合は「改善提案を {truncated} 件省略しました（重要度の高い上位項目を優先）」を追記する。失敗時: `{force_mode}` が true なら自動で1回リトライし、再失敗時は中止する。`{force_mode}` が false なら AskUserQuestion で「Phase 3 Step 1 が失敗しました: {エラー内容}。リトライしますか？」と確認し、「リトライ」/「中止」の選択肢を提供する。

問題が0件（critical + improvement = 0）の場合:
- positive が 0件なら「全レビューファイルが空です。レビュー失敗の可能性があります。」と警告
- positive が 1件以上なら「全レビューアーが問題を検出しませんでした（良い点: {K}件）。スキルは品質基準を満たしています。」とテキスト出力
- Phase 4-6 をスキップし、Phase 7 へ進む

#### Step 2: コンフリクト解決（conflicts > 0 の場合のみ）

`{work_dir}/conflicts.md` を Read し、各コンフリクトを以下の判定基準ヒントに基づいて解決する。判定基準で解決できない場合: `{force_mode}` が true なら conflicts.md で先に記載された側（Side A）を自動採用し「force モード: コンフリクト {CONF-ID} は Side A を自動採用」とテキスト出力する。`{force_mode}` が false なら `AskUserQuestion` でユーザーにトレードオフを提示し選択してもらう。

**判定基準ヒント**:
- 効率性「確認ポイントを削減」↔ UX「確認が必要」→ 不可逆操作のガードならUX優先
- 効率性「指示を短縮」↔ 安定性「詳細な指示が必要」→ 複数解釈が生じるなら安定性優先
- アーキテクチャ「テンプレート化」↔ 効率性「インラインが効率的」→ 7行超ならテンプレート化
- アーキテクチャ「外部参照を除去」↔ アーキテクチャ「パターン準拠に必要」→ スキル内にコピー可能ならスコープ優先
- 有効性「フェーズを追加すべき」↔ 効率性「フェーズが多すぎる」→ データフロー不全が存在する場合は有効性優先
- 有効性「判定ロジック変更」↔ 安定性「判定フォーマット維持」→ 出力形式の維持が目的達成に影響しないなら安定性優先
- 有効性「エッジケース対応追加」↔ UX「確認ポイント追加」→ 致命的エラーを引き起こすなら有効性優先

解決結果に基づき、`{work_dir}/findings.md` から採用しない側の指摘を Edit で削除する。

#### Step 3: 結果提示

「検出: 重大 {N}件, 改善 {M}件, 良い点 {K}件, コンフリクト: {N}件解決」の形式でサマリをテキスト出力する。

---

### Phase 4: フィードバック個別承認 + 改善計画生成

テキスト出力: `## Phase 4: フィードバック個別承認`

#### Step 1: フィードバック個別承認

`{work_dir}/findings.md` を Read し、各指摘（`###` ブロック単位）を順に提示する。`{total}` = 重大な問題 + 改善提案の合計件数、`{N}` = 1 から開始するカウンター。

`{force_mode}` が true の場合: 全件を承認としてループを省略し、テキスト出力「force モード: 全 {total} 件を自動承認」。Step 2 へ進む。

`{force_mode}` が false の場合: 各指摘に対して以下をテキスト出力する:
```
### [{N}/{total}] {ID}: {タイトル} ({重大度: critical/improvement})
- レビューアー: {レビューアー名}
- 対象: {対象ファイル:セクション}
- 内容: {問題内容}
- 推奨: {改善案}

（空行）
```

続けて `AskUserQuestion` で方針確認:
- **「承認」**: この指摘を改善計画に含める。次の指摘へ進む
- **「スキップ」**: この指摘を改善計画から除外する。次の指摘へ進む
- **「残りすべて承認」**: この指摘を含め、未確認の全指摘を承認としてループを終了する
- **「キャンセル」**: 全指摘の確認を中止し、Phase 7 へ直行する

#### Step 2: 承認結果の保存

承認された指摘を `{work_dir}/approved-findings.md` に Write で保存する。
フォーマット:
```
# 承認済みフィードバック

承認: {承認数}/{total}件（スキップ: {スキップ数}件）

## 重大な問題

### {ID}: {タイトル} [{レビューアー}]
- 対象: {対象}
- {問題内容}
- 改善案: {改善案}
- **ユーザー判定**: 承認

## 改善提案

（同形式で承認された改善提案を記載）
```

承認数が 0 の場合: 「全ての指摘がスキップされました。改善の適用はありません。」とテキスト出力する。

#### Step 2b: スキップされた指摘の resolved-issues.md 記録

スキップ数 > 0 の場合、スキップされた各指摘を `{resolved_issues_path}` に追記する:
- findings.md の各スキップ指摘から、対象ファイル名（`## {ファイル名}` の見出し配下に配置）、対象セクション（`### {セクション} | {カテゴリ}` 形式の見出し）、問題カテゴリを抽出する
- 問題カテゴリは指摘の内容から以下のいずれかを選択: `ambiguity`, `format-stability`, `condition-branch`, `idempotency`, `reference-integrity`, `redundant-process`, `data-passing`, `ux-guard`, `template-scope`, `error-resilience`, `data-flow`, `edge-case`, `scope-boundary`
- 同一の (file, section, category) エントリが既に存在する場合は Edit で上書きし、存在しない場合は該当ファイルの見出しの末尾に追記する
- フォーマット:
  ```
  ### {セクション} | {カテゴリ}
  - 指摘: {指摘タイトル}
  - 対応: ユーザー判断でスキップ
  - run: {timestamp}
  ```

承認数が 0 の場合: Phase 7 へ直行する。

#### Step 3: 改善計画生成（サブエージェントに委譲）

テキスト出力: `改善計画を生成しています...`

`Task`（sonnet）で `{skill_audit_path}/templates/consolidate-findings.md` に委譲する。パス変数:
- `{skill_path}`, `{skill_name}`, `{analysis_path}`: `{work_dir}/analysis.md`, `{findings_path}`: `{work_dir}/approved-findings.md`, `{plan_save_path}`: `{work_dir}/improvement-plan.md`

サブエージェント完了後、サマリ（modified, created, deleted_recommended, total_findings_addressed）をテキスト出力する。失敗時: `{force_mode}` が true なら自動で1回リトライし、再失敗時は中止する。`{force_mode}` が false なら AskUserQuestion で「改善計画生成が失敗しました: {エラー内容}。リトライしますか？」と確認し、「リトライ」/「中止」の選択肢を提供する。

#### Step 4: 改善計画サマリ

テキスト出力:
```
改善計画生成完了。Phase 5 で適用します。
詳細: {work_dir}/improvement-plan.md
```

Phase 5 へ進む。

---

### Phase 5: 改善適用（サブエージェントに委譲）

`Task`（sonnet）で `{skill_audit_path}/templates/apply-improvements.md` に委譲する。パス変数:
- `{skill_path}`, `{skill_name}`, `{plan_path}`: `{work_dir}/improvement-plan.md`

サブエージェント完了後、テキスト出力: `## Phase 5: 改善適用完了` + 返答内容。失敗時: `{force_mode}` が true なら自動で1回リトライし、再失敗時は中止する。`{force_mode}` が false なら AskUserQuestion で「Phase 5 が失敗しました: {エラー内容}。リトライしますか？」と確認し、「リトライ」/「中止」の選択肢を提供する。

---

### Phase 6: 軽量検証（サブエージェントに委譲）

`Task`（sonnet）で `{skill_audit_path}/templates/verify-improvements.md` に委譲する。パス変数:
- `{skill_path}`, `{skill_name}`, `{plan_path}`: `{work_dir}/improvement-plan.md`
- `{analysis_path}`: `{work_dir}/analysis.md`, `{quality_criteria_path}`: `{skill_audit_path}/quality-criteria.md`
- `{findings_path}`: `{work_dir}/approved-findings.md`, `{verification_save_path}`: `{work_dir}/verification.md`

サブエージェント完了後、テキスト出力: `## Phase 6: 検証結果` + 返答内容。失敗時: `{force_mode}` が true なら自動で1回リトライし、再失敗時は中止する。`{force_mode}` が false なら AskUserQuestion で「Phase 6 が失敗しました: {エラー内容}。リトライしますか？」と確認し、「リトライ」/「中止」の選択肢を提供する。

**検証結果に基づく resolved-issues.md の更新**:

`{work_dir}/verification.md` を Read し、「解決済み」判定の指摘を `{resolved_issues_path}` に記録する:
- 各解決済み指摘について `{work_dir}/approved-findings.md` と `{work_dir}/improvement-plan.md` を参照し、対象ファイル名、対象セクション、問題カテゴリ、改善内容の要約（1行）を抽出する
- 問題カテゴリは Phase 4 Step 2b と同じ一覧から選択
- 同一の (file, section, category) エントリが既に存在する場合は Edit で上書きし、存在しない場合は該当ファイルの見出しの末尾に追記する
- 「部分的解決」の指摘は記録しない（次回 run で再検出させるため）
- フォーマット:
  ```
  ### {セクション} | {カテゴリ}
  - 指摘: {指摘タイトル}
  - 対応: {改善内容の要約}
  - run: {timestamp}
  ```

**検証結果の処理**:
- 未解決項目なし（not_addressed = 0 かつ new_issues = 0）→ Phase 7 へ進む
- 未解決項目あり → 以下の対応方針選択へ

#### 対応方針選択

`{force_mode}` が true の場合: 選択肢「発生した問題にだけ対処する」を自動選択し「force モード: 未解決項目に対して個別対処を自動選択」とテキスト出力する。個別対処フローへ進む。

`{force_mode}` が false の場合: `AskUserQuestion` で方針を確認する:
- **「対応しない」**: Phase 7 へ直行する
- **「発生した問題にだけ対処する」**: 個別対処フローへ進む
- **「やり直す（Phase 2-6 を再実行）」**: Phase 2 に戻り、全フローを再実行する（再実行後も同様に検証・選択を繰り返す）

#### 個別対処フロー

テキスト出力: `### 未解決項目の確認`

1. `{work_dir}/verification.md` を Read し、未解決項目（not_addressed + partial）の ID を抽出する。次に `{work_dir}/approved-findings.md` を Read し、抽出した ID で突合して各項目の詳細（タイトル、レビューアー名、対象、内容）を取得する。verification.md の備考も併せて保持する
2. `{retry_total}` = 未解決項目の合計件数、`{retry_N}` = 1 から開始するカウンター
3. `{force_mode}` が true の場合: 全件を承認としてループを省略し、テキスト出力「force モード: 未解決 {retry_total} 件を全て自動承認」。手順 5 へ進む。
4. `{force_mode}` が false の場合: 各未解決項目に対して以下をテキスト出力する:
   ```
   ### [{retry_N}/{retry_total}] {ID}: {タイトル} ({判定: not_addressed/partial})
   - レビューアー: {レビューアー名}
   - 対象: {対象ファイル:セクション}
   - 内容: {問題内容}
   - 検証結果: {verification.md の備考}

   （空行）
   ```
   続けて `AskUserQuestion` で方針確認:
   - **「承認」**: この項目の追加修正を行う。次の項目へ進む
   - **「スキップ」**: この項目の追加修正を行わない。次の項目へ進む
   - **「残りすべて承認」**: この項目を含め、未確認の全項目を承認としてループを終了する
   - **「キャンセル」**: 確認を中止し、Phase 7 へ直行する
5. 承認された項目を `{work_dir}/retry-approved-findings.md` に Write で保存する（Phase 4 Step 2 と同じフォーマット）
6. 承認数 > 0 の場合:
   - テキスト出力: `追加修正の改善計画を生成しています...`
   - `Task`（sonnet）で `{skill_audit_path}/templates/consolidate-findings.md` に委譲する。パス変数:
     - `{skill_path}`, `{skill_name}`, `{analysis_path}`: `{work_dir}/analysis.md`（注: 改善前の構造分析。テンプレート内で対象ファイルを直接 Read するため実用上は問題ない）, `{findings_path}`: `{work_dir}/retry-approved-findings.md`, `{plan_save_path}`: `{work_dir}/retry-improvement-plan.md`
   - 上記 Task 完了後に `Task`（sonnet）で `{skill_audit_path}/templates/apply-improvements.md` に委譲する。パス変数:
     - `{skill_path}`, `{skill_name}`, `{plan_path}`: `{work_dir}/retry-improvement-plan.md`
   - サブエージェント完了後、テキスト出力: `追加修正適用完了` + 返答内容
   - 軽量再検証: Glob で `{skill_path}/templates/*.md` を列挙し、各テンプレート内の `{variable}` プレースホルダを抽出する。SKILL.md 内のパス変数定義と照合し、未定義変数・未参照変数・不在ファイル参照を検出する。不整合がある場合はテキスト出力で警告する:
     `⚠ リトライ後の参照整合性チェックで不整合を検出: {不整合の内容}`
7. Phase 7 へ進む

---

### Phase 7: 完了サマリ

完了サマリをテキスト出力する:

```
## skill_audit 完了
- 対象スキル: {skill_name}
- スキルパス: {skill_path}
- レビュー観点: 5 (stability, efficiency, ux, architecture, effectiveness)
- 検出: 重大 {N}件, 改善提案 {N}件
- 承認: {承認数}/{total}件（スキップ: {スキップ数}件）
- コンフリクト: {N}件 (合意{N}/ユーザー判断{N})
- 適用改善: {N}件
- 検証結果: {PASS / 未解決項目あり}
  （未解決項目ありの場合のみ次の行を追加）
  - 対応: {対応しない / 個別対処（{承認数}件適用, {スキップ数}件スキップ）/ やり直し}
- 変更: {N}件修正, {M}件新規
- 作業ディレクトリ: {work_dir}
```
