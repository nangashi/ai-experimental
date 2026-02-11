---
allowed-tools: Glob, Grep, Read, Write, Edit, Task, AskUserQuestion
description: スキルを多角的に批判レビューし、コンフリクト解決を経て改善・検証するスキル
---

指定されたスキルを4つの品質観点（安定性・効率性・UX・アーキテクチャ）で並列レビューし、コンフリクト解決を経て改善を適用します。

## 使い方

```
/skill_improve <skill_path>
```

- `skill_path`: スキルディレクトリの絶対パスまたは相対パス（SKILL.md を含むディレクトリ）

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
2. `{skill_path}` を絶対パスに変換する
3. Read で `{skill_path}/SKILL.md` の存在を確認する。不在の場合はエラー出力して終了:
   「SKILL.md が見つかりません: {skill_path}/SKILL.md. スキルディレクトリを確認してください。」
4. Glob で `{skill_path}/**/*.md` を実行し `{file_list}` を構成する。0件の場合はエラー出力して終了:
   「{skill_path} 内に .md ファイルが見つかりません。SKILL.md を含むスキルディレクトリを指定してください。」
5. `{skill_name}` = `{skill_path}` の末尾ディレクトリ名。`{work_dir}` = `prompt-improve/skill-improve-{skill_name}`
6. 自己改善検出: `{skill_path}` が `.claude/skills/skill_improve` を含む場合は警告出力:
   「注意: このスキル自身を改善対象としています。変更は次回の実行から反映されます。」
7. `AskUserQuestion` で実行モードを選択する:
   - **Standard（推奨）**: 各フェーズの中間結果を確認できます
   - **Fast**: 中間確認をスキップし、改善計画の承認のみ行います

---

### Phase 1: スキル構造分析（サブエージェントに委譲）

テキスト出力: `## Phase 1: スキル構造分析`

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/skill_improve/templates/analyze-skill-structure.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{skill_path}`: スキルディレクトリの絶対パス
- `{skill_name}`: スキル名
- `{file_list}`: スキル内の全ファイルパスリスト（改行区切り）
- `{analysis_save_path}`: `{work_dir}/analysis.md` の絶対パス

サブエージェント完了後、返答内容（サマリ）をテキスト出力する（Standard/Fast 共通）。Task が失敗した場合はエラー内容をテキスト出力し、AskUserQuestion で「リトライ」/「中止」を確認する。

---

### Phase 2: 並列サブエージェントレビュー

テキスト出力:
```
## Phase 2: 多角的並列レビュー
- レビュータスク: 4件
- レビューアー: stability, efficiency, ux, architecture
- 対象スキル: {skill_name}
```

以下の4つを `Task` ツールで**1つのメッセージで並列に**起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

| テンプレート | 結果保存先 |
|-------------|-----------|
| `reviewer-stability.md` | `{work_dir}/review-stability.md` |
| `reviewer-efficiency.md` | `{work_dir}/review-efficiency.md` |
| `reviewer-ux.md` | `{work_dir}/review-ux.md` |
| `reviewer-architecture.md` | `{work_dir}/review-architecture.md` |

各レビューアーへのプロンプト:
```
`.claude/skills/skill_improve/templates/reviewer-{perspective}.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- {skill_path}: {値}
- {analysis_path}: {work_dir}/analysis.md の絶対パス
- {quality_criteria_path}: .claude/skills/skill_improve/quality-criteria.md の絶対パス
- {findings_save_path}: {work_dir}/review-{perspective}.md の絶対パス
- {skill_name}: {値}
```

4件全ての Task 完了後、テキスト出力:
```
レビュー完了: {成功数}/4件
```

成功数が4未満の場合:
- 失敗したレビューアー名をテキスト出力する
- 成功数が3件以上: 「最低基準（3件）を満たしているため、続行します。」と出力し、Phase 3 へ進む
- 成功数が2件以下: AskUserQuestion で「レビューが{成功数}/4件のみ完了しました。」「続行」/「中止」を確認する

---

### Phase 3: フィードバック統合・コンフリクト解決

テキスト出力: `## Phase 3: フィードバック統合・コンフリクト解決`

#### Step 1: フィードバック分類

`{work_dir}/review-*.md` を Read で読み込み、4件のレビュー結果を以下に分類する:
1. **重大な問題**: スキルの機能・正確性に影響する問題
2. **改善提案**: 品質向上に有効な変更
3. **良い点**: 現状維持でよい点

#### Step 2: コンフリクト検出

4件のレビュー結果を比較し、コンフリクトを検出する:
1. 各レビュー結果の「重大な問題」「改善提案」を対象ファイル:セクション でグループ化する
2. 同一箇所（ファイル+セクション/行番号が一致）に対する指摘を抽出する
3. 以下の相反パターンを検出する:
   - 削除 vs 追加
   - 簡略化 vs 詳細化
   - インライン化 vs テンプレート化
   - 確認削減 vs 確認追加
4. 検出したコンフリクト（あれば）を次ステップで解決する

**想定コンフリクトパターンと判定基準ヒント**:
- 効率性「確認ポイントを削減」↔ UX「確認が必要」→ 不可逆操作のガードならUX優先
- 効率性「指示を短縮」↔ 安定性「詳細な指示が必要」→ 複数解釈が生じるなら安定性優先
- アーキテクチャ「テンプレート化」↔ 効率性「インラインが効率的」→ 7行超ならテンプレート化
- アーキテクチャ「外部参照を除去（ファイルスコープ）」↔ アーキテクチャ「パターン準拠に必要（委譲モデル）」→ スキル内にコピー可能ならスコープ優先

#### Step 3: コンフリクト解決（コンフリクトがある場合のみ）

判定基準ヒントに基づいて親が直接解決する。判定基準で解決できない場合のみ `AskUserQuestion` でユーザーにトレードオフを提示し選択してもらう。

#### Step 4: 結果提示

Standard mode: 全分類結果（重大/改善/良い点）+ コンフリクト解決結果をテキスト出力する。
Fast mode: 「検出: 重大 {N}件, 改善 {M}件, 良い点 {K}件」の形式でサマリをテキスト出力する。コンフリクト未解決時のみ `AskUserQuestion`。

問題が0件（重大 + 改善 = 0）の場合:
- 「全4レビューアーが問題を検出しませんでした。スキルは品質基準を満たしています。」とテキスト出力する
- Phase 4-6 をスキップし、Phase 7 へ進む

Phase 3 完了後、分類済みフィードバック（重大な問題 + 改善提案）を `{work_dir}/findings.md` に Write で保存する。
フォーマット:
```
## 重大な問題
{各重大な問題の内容}

## 改善提案
{各改善提案の内容}
```

---

### Phase 4: 改善計画生成 + ユーザー承認（サブエージェントに委譲）

テキスト出力: `## Phase 4: 改善計画生成`

`Task`（sonnet）で `templates/consolidate-findings.md` に委譲する。パス変数:
- `{skill_path}`, `{skill_name}`, `{analysis_path}`: `{work_dir}/analysis.md`, `{findings_path}`: `{work_dir}/findings.md`, `{plan_save_path}`: `{work_dir}/improvement-plan.md`

サブエージェント完了後、サマリをテキスト出力する。失敗時は AskUserQuestion で「リトライ」/「中止」を確認する。

**必須承認ポイント（Fast mode でも省略不可）**:

`{work_dir}/improvement-plan.md` を Read し全内容をテキスト出力後、`AskUserQuestion` で承認確認:
- **「全て承認」**: Phase 5 へ / **「修正要望あり」**: 要望を反映後 Phase 5 へ / **「キャンセル」**: Phase 7 へ直行

---

### Phase 5: 改善適用（サブエージェントに委譲）

`Task`（sonnet）で `templates/apply-improvements.md` に委譲する。パス変数:
- `{skill_path}`, `{skill_name}`, `{plan_path}`: `{work_dir}/improvement-plan.md`

サブエージェント完了後、テキスト出力: `## Phase 5: 改善適用完了` + 返答内容。失敗時は AskUserQuestion で「リトライ」/「中止」を確認する。

---

### Phase 6: 軽量検証（サブエージェントに委譲）

`Task`（sonnet）で `templates/verify-improvements.md` に委譲する。パス変数:
- `{skill_path}`, `{skill_name}`, `{plan_path}`: `{work_dir}/improvement-plan.md`
- `{analysis_path}`: `{work_dir}/analysis.md`, `{quality_criteria_path}`: `.claude/skills/skill_improve/quality-criteria.md`
- `{findings_path}`: `{work_dir}/findings.md`, `{verification_save_path}`: `{work_dir}/verification.md`

サブエージェント完了後、テキスト出力: `## Phase 6: 検証結果` + 返答内容。失敗時は AskUserQuestion で「リトライ」/「中止」を確認する。

**判定結果の処理**:
- `verdict: PASS` → Phase 7 へ進む
- `verdict: NEEDS_ATTENTION`:
  - `{retry_count}` が 0: AskUserQuestion で「このまま受け入れる」/「追加修正を実施」/「全変更を取り消す」を確認
    - 「追加修正」→ `{retry_count} = 1` とし Phase 5 に戻る
    - 「全変更取消」→ 「git checkout -- {skill_path} で復元可能」と出力し Phase 7 へ
  - `{retry_count}` が 1: 検証結果をテキスト出力し Phase 7 へ（再試行上限）

---

### Phase 7: 完了サマリ

完了サマリをテキスト出力する:

```
## skill_improve 完了
- 対象スキル: {skill_name}
- スキルパス: {skill_path}
- レビュー観点: 4 (stability, efficiency, ux, architecture)
- 検出: 重大 {N}件, 改善提案 {N}件
- コンフリクト: {N}件 (合意{N}/ユーザー判断{N})
- 適用改善: {N}件
- 検証結果: {verdict}
- 変更: {N}件修正, {M}件新規
- 作業ディレクトリ: {work_dir}
```
