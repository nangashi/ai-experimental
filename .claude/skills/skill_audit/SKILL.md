---
allowed-tools: Bash, Glob, Grep, Read, Write, Edit, Task, AskUserQuestion
description: Validates skill definitions for reference integrity, variable consistency, context efficiency, and workflow structure
disable-model-invocation: true
---

指定されたスキルの定義ファイルを静的に検証し、参照整合性・変数整合性・コンテキスト効率・ワークフロー構造の問題を検出します。検出した問題はユーザーに個別提示し、承認された項目のみ修正を適用します。

## 使い方

```
/skill_audit <skill_path>
```

- `skill_path`: スキルディレクトリのパス（SKILL.md を含むディレクトリ）

## コンテキスト節約の原則

1. **参照ファイルは使用する Phase でのみ読み込む**（先読みしない）
2. **大量コンテンツの分析はサブエージェントに委譲する**
3. **サブエージェントからの返答は最小限にする**（詳細はファイルに保存させる）
4. **親コンテキストには要約・メタデータのみ保持する**
5. **サブエージェント間のデータ受け渡しはファイル経由で行う**（親を中継しない）

## ワークフロー

Phase 0 → 1 → 2 → 3 を順に実行します。

---

### Phase 0: 初期化

テキスト出力: `## Phase 0: 初期化`

1. 引数から `{skill_path}` を取得する（未指定の場合は `AskUserQuestion` で確認）
2. `{skill_path}` を絶対パスに変換する
3. Read で `{skill_path}/SKILL.md` の存在を確認する。不在の場合はエラー出力して終了:
   「SKILL.md が見つかりません: {skill_path}/SKILL.md」
4. Glob で `{skill_path}/**/*.md` を実行し `{file_list}` を構成する
5. `{skill_name}` = `{skill_path}` の末尾ディレクトリ名
6. `{work_dir}` = `.skill_output/skill_audit/{skill_name}` の絶対パス
7. `mkdir -p {work_dir}` を実行する（Bash）
8. `{skill_audit_path}` = `.claude/skills/skill_audit` の絶対パス
9. Write で `{work_dir}/file-list.txt` に `{file_list}` を保存する（改行区切り）

---

### Phase 1: 並列分析

テキスト出力: `## Phase 1: スキル分析`

以下の2つを `Task` ツールで **1つのメッセージで並列に** 起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

#### 1-A: 参照・変数整合性チェック

```
`{skill_audit_path}/templates/reference-analysis.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{skill_path}`: {値}
- `{skill_name}`: {値}
- `{file_list_path}`: {work_dir}/file-list.txt の絶対パス
- `{findings_save_path}`: {work_dir}/findings-reference.md の絶対パス
```

#### 1-B: コンテンツ・ワークフロー分析

```
`{skill_audit_path}/templates/content-analysis.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{skill_path}`: {値}
- `{file_list_path}`: {work_dir}/file-list.txt の絶対パス
- `{findings_save_path}`: {work_dir}/findings-content.md の絶対パス
```

2件とも完了後、各返答のサマリ（検出件数）をテキスト出力する。

---

### Phase 2: 検出結果の提示と対応

テキスト出力: `## Phase 2: 検出結果`

1. `{work_dir}/findings-reference.md` と `{work_dir}/findings-content.md` を Read する
2. 両ファイルから `### SK-` で始まる各 finding ブロックを抽出し、severity 順（error → warning → info）でソートする
3. findings が 0 件の場合: 「問題は検出されませんでした」と出力し Phase 3 へ

`{total}` = 全 finding の件数、`{N}` = 1 から開始するカウンター。

各 finding に対して以下をテキスト出力する:

```
### [{N}/{total}] {ID}: {タイトル}
- **チェック**: {Check の値} ({チェック名})
- **重要度**: {Severity の値}
- **場所**: {Location の値}
- **問題**: {Problem の値}
- **修正案**: {Fix の値}
- **自動修正**: {Auto の値}
```

チェック名の対応表:
- A1: 存在しないファイル参照, A2: 他スキルへの参照, A3: 孤立ファイル, A4: old/ 参照
- B1: 未定義パス変数, B2: 未使用パス変数, B3: パス変数名の不一致
- C1: 大きなインラインコンテンツ, C2: 返答最小化指示の欠如, C3: コンテキスト消費量
- D1: 3ホップパターン, D2: 書き込み/読み込み不整合
- E1: Phase/Step 番号の不整合, E3: 到達不能な分岐

続けて `AskUserQuestion` で確認する:
- **対応する** — この問題を修正する
- **スキップ** — この問題をスキップする
- **残りすべて対応** — 未確認の全項目を対応する
- **残りすべてスキップ** — 残りを全てスキップし Phase 3 へ

#### 「対応する」が選択された場合

finding の Auto フィールドが `yes` の場合:
- Auto フィールドの括弧内に記載された具体的操作を Edit/Write/Bash で直接実行する
- 実行結果をテキスト出力する

finding の Auto フィールドが `no` の場合:
- Fix の内容を元に詳細な修正ガイダンスをテキスト出力する
- 「この修正は構造変更を伴うため、手動での対応を推奨します」と付記する
- 対応カウントは「手動対応推奨」として集計する

---

### Phase 3: 完了サマリ

テキスト出力:

```
## skill_audit 完了
- 対象: {skill_name} ({skill_path})
- 検出: {total}件 (error: {N}, warning: {N}, info: {N})
- 自動修正: {auto_fixed}件
- 手動対応推奨: {manual}件
- スキップ: {skipped}件
- 作業ディレクトリ: {work_dir}
```
