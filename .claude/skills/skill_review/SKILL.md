---
allowed-tools: Bash, Glob, Grep, Read, Write, Edit, Task, AskUserQuestion
description: Reviews skill definitions for structural understanding and design quality improvement
disable-model-invocation: true
---

指定されたスキル定義を分析し、構造の可視化・コンテキスト効率の定量化・設計パターンのレビューを行います。

## 使い方

```
/skill_review <skill_path>
```

- `skill_path`: スキルディレクトリのパス（SKILL.md を含むディレクトリ）

## パス変数

- `{skill_dir}`: このスキル（skill_review）のディレクトリの絶対パス
- `{skill_path}`: 対象スキルディレクトリの絶対パス
- `{skill_name}`: 対象スキルのディレクトリ名
- `{work_dir}`: `.skill_output/skill_review/{skill_name}` の絶対パス

## ワークフロー

Phase 0 → 1 → 2 → 3

---

### Phase 0: 初期化

1. 引数から `{skill_path}` を取得する（未指定の場合は AskUserQuestion で確認）
2. `{skill_path}` を絶対パスに変換する
3. Read で `{skill_path}/SKILL.md` の存在を確認する。不在の場合はエラー出力して終了
4. Glob で `{skill_path}/**/*.md` を実行し `{file_list}` を構成する
5. `{skill_name}` = `{skill_path}` の末尾ディレクトリ名
6. `{work_dir}` = `.skill_output/skill_review/{skill_name}` の絶対パス
7. `mkdir -p {work_dir}` を実行する（Bash）
8. `{skill_dir}` = `.claude/skills/skill_review` の絶対パス
9. Write で `{work_dir}/file-list.txt` に `{file_list}` を保存する（改行区切り）

---

### Phase 1: 並列分析

以下の2つを Task ツールで **1つのメッセージで並列に** 起動する（subagent_type: "general-purpose", model: "sonnet"）:

#### 1-A: 構造分析

```
`{skill_dir}/templates/structure-analysis.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{skill_path}`: {値}
- `{skill_name}`: {値}
- `{file_list_path}`: {work_dir}/file-list.txt の絶対パス
- `{report_save_path}`: {work_dir}/structure-report.md の絶対パス
```

#### 1-B: 設計レビュー

```
`{skill_dir}/templates/design-review.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{skill_path}`: {値}
- `{skill_name}`: {値}
- `{skill_dir}`: {値}
- `{file_list_path}`: {work_dir}/file-list.txt の絶対パス
- `{findings_save_path}`: {work_dir}/design-findings.md の絶対パス
```

2件とも完了後、各返答のサマリをテキスト出力し Phase 2 へ。

---

### Phase 2: レポート提示

#### Step 1: 事実ベースの分析結果

`{work_dir}/structure-report.md` を Read し、内容をそのままテキスト出力する。

#### Step 2: 設計レビュー結果

`{work_dir}/design-findings.md` を Read する。

findings が 0 件の場合: 「設計上の指摘はありませんでした」と出力し Phase 3 へ。

`{total}` = 全 finding の件数。各 finding に対して重要度の高い順に1件ずつテキスト出力する:

```
### [{N}/{total}] {ID}: {パターン名}
- **重要度**: {高/中/低}
- **場所**: {ファイル名}:{セクション名 or 行範囲}
- **問題**: {具体的な問題の説明}
- **改善案**: {具体的な改善提案}
- **根拠**: {instruction ファイル名}「{該当原則の引用}」
```

続けて AskUserQuestion で確認する:
- **了解** — 確認済み、次の指摘へ
- **対応する** — この指摘に基づいて修正を適用する
- **スキップ** — この指摘を飛ばす
- **残りすべてスキップ** — 残りを全てスキップし Phase 3 へ
- 自由入力 — 議論・質問に応答してから再度確認

「対応する」が選択された場合:
- finding の改善案を具体的な Edit 操作に変換して実行する
- 構造変更を伴う場合は変更内容を説明し、ユーザーの追加承認を得てから実行する

---

### Phase 3: 完了サマリ

```
## skill_review 完了
- 対象: {skill_name} ({skill_path})
- 構造分析: フロー図・コンテキストマップ・参照チェック済み
- 設計レビュー: {total}件 (高: {N}, 中: {N}, 低: {N})
- 対応: {fixed}件, 了解: {ack}件, スキップ: {skipped}件
- 作業ディレクトリ: {work_dir}
```
