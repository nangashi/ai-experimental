---
allowed-tools: Glob, Grep, Read, Write, Edit, Task, AskUserQuestion
description: 調査メモから行動指示を抽出し、重複・矛盾を検知しながら構造化instructionに反映するスキル
disable-model-invocation: true
---

`docs/knowledge/` の調査メモ・実験結果から AI の行動指示（instruction）を抽出し、既存 instruction との重複・矛盾を検知しながら `.claude/instructions/` に反映します。

## 使い方

```
/instruction_extract <source_path>
```

- `source_path`: `docs/knowledge/` 配下のマークダウンファイル

## 出力先

- 中間ファイル: `.skill_output/instruction_extract/{basename}.med.md`（全候補のフィルタ評価 + 通過項目の抽出内容）
- instruction ファイル: `.claude/instructions/*.md`
- 一覧: `CLAUDE.md` の `## Instructions and Knowledge` セクション

## 記述原則

instruction ファイルは AI がコンテキストとして読み込む前提で記述する。目標は「AI が会話コンテキストなしで読んで、正確かつ安定した判断に使える行動指示」。

### instruction ファイルのフォーマット

```markdown
# {タイトル}

{概要。1-2文}

## {指示タイトル}

- **scope**: {適用される状況}
- **action**: {AIが取るべき行動}
- **rationale**: {根拠。定量データがあれば含む}
- **conditions**: {効果が逆転・無効化する条件。なければ省略}
- **source**: docs/knowledge/{filename}.md
```

### 残すべき情報

- **判断基準**: 閾値、条件分岐、「○○の場合は△△」は省略しない
- **理由**: 理由がないと例外ケースで誤適用される
- **代表例**: 抽象的な指針には最低1つの具体例を添える

### 削ってよい情報

- 経緯の詳細、試行錯誤の過程
- 感想、冗長な修飾
- **AIが既に知っている情報**: 公式ドキュメントの基本事項、LLMの訓練データに広く含まれる公知の手法・原則
- **出典・ソース情報**: 出典ラベル（「○○研究より」等）は不要。定量データや根拠自体は残すが、どこから得たかは記載しない（source フィールドで元ファイルを追跡する）

## ワークフロー

Phase 1（抽出 → .med.md 生成）→ Phase 2（照合 → 判定テーブル生成）→ Phase 3（反映 → per-item でユーザー承認しながら更新）

---

### Phase 1: 抽出

#### Step 1: 初期化

1. `{source_path}` の存在を確認する
2. `{basename}` をファイル名（.md 除去）から導出する
3. `{med_version}` = 3（※ extraction.md のフィルタ基準やフォーマット変更時にバンプする）
4. `{med_path}` = `.skill_output/instruction_extract/{basename}.med.md` を設定する
5. `{med_path}` が既に存在するか確認する:
   - 存在する場合: frontmatter の `med_version` を読み取る
     - バージョン一致 → テキスト出力「med ファイルは最新です（v{med_version}）。Phase 2 から再開します。」→ Phase 2 へスキップ
     - バージョン不一致 → テキスト出力「抽出条件が更新されています（v{旧} → v{med_version}）。再抽出します。」→ 再抽出へ進む
   - 存在しない場合 → 新規抽出へ進む
6. CLAUDE.md を Read し、`## Instructions and Knowledge` セクションから use-when テキスト ↔ ファイルパスの対応表を取得する → `{use_when_map}`

#### Step 2: 抽出

`Task` ツールでサブエージェントに委譲する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

> 以下の手順で行動指示を抽出してください。
>
> 1. Read で `{source_path の絶対パス}` を読み込む
> 2. Read で `{extraction テンプレートの絶対パス}` を読み込む
> 3. テンプレートの指示に従い、行動指示を抽出する
> 4. Write で `{med_path の絶対パス}` に出力する
> 5. 「完了」とだけ返答する
>
> パス変数:
> - source_path: `{source_path の絶対パス}`
> - med_path: `{med_path の絶対パス}`
> - extraction_template: `{extraction テンプレートの絶対パス}`
> - med_version: `{med_version}`
>
> use-when 対応表:
> {use_when_map の内容をここに展開}

#### Step 3: 新規 use-when の解決

1. 生成された `{med_path}` を Read する
2. `proposed-use-when` フィールドがある項目を `{unresolved}` リストに収集する
3. `{unresolved}` が空でない間、以下をループする:
   a. ソース文書の frontmatter `scope` をベースに、1つの新カテゴリ候補を導出する（2回目以降は残りの項目の proposed-use-when から導出）
   b. use-when はトリガー条件（いつ必要か）であり、トピックラベル（何についてか）ではない
      - Bad: 「推論時コンピュート拡張の設定」（トピックラベル）
      - Good: 「推論時コンピュート拡張手法を選択するとき」（判断場面）
   c. `{unresolved}` の各項目を候補 use-when に対して評価し、適合する項目と適合しない項目に分類する
   d. テキスト出力する:
      ```
      ## 新規 use-when の提案 [{round}/{total_rounds_unknown}]

      提案: use-when「{候補 use-when テキスト}」
      提案ファイル名: {slug}.md
      適合する項目 ({M}件):
      - KE-{NNN}: {タイトル}
      - KE-{NNN}: {タイトル}

      適合しない項目 ({K}件):
      - KE-{NNN}: {タイトル}（→ 次のラウンドで再分類）

      選択肢:
      1. この use-when で作成する
      2. use-when またはファイル名を修正する
      3. キャンセル（未分類のまま残す）
      ```
   e. ユーザーの応答を待ち、選択に従って処理する
   f. 承認後:
      - `.claude/instructions/{slug}.md` を Write で作成（タイトルと概要のみ）
      - CLAUDE.md の Instructions and Knowledge テーブルに行を追加（Edit）
      - 適合項目の `{med_path}` の use-when を確定値で更新（Edit）
      - `{use_when_map}` を更新する
      - 適合しなかった項目で `{unresolved}` を更新し、ループを続行する
   g. キャンセルの場合: 残りの項目は `proposed-use-when` のまま残してループを終了する
4. `proposed-use-when` がない場合（ループ不要）: そのまま次へ

#### Step 4: 抽出サマリの表示

テキスト出力:
```
## Phase 1: 抽出完了
- ソース: {source_path}
- 中間ファイル: {med_path}（v{med_version}、通過 {M}/{N}）
- 抽出項目数: {M}
- ルーティング:
  - → {instruction_file_1}: {n1}件
  - → {instruction_file_2}: {n2}件
```

---

### Phase 2: 照合

#### Step 1: ルーティング

1. `{med_path}` を Read する
2. 判定が PASS の項目のみを対象とする（FILTERED 項目はスキップ）
3. 各項目の `use-when` で対象 `.claude/instructions/` ファイルを特定する（`{use_when_map}` で完全一致検索）
4. 対象ファイル別に項目をグルーピングする

#### Step 2: セマンティック照合

対象ファイルごとに `Task` ツールでサブエージェントに委譲する（`subagent_type: "general-purpose"`, `model: "sonnet"`）。
対象ファイルが複数ある場合は**並列**で実行する。

> 以下の手順で照合を実行してください。
>
> 1. Read で `{comparison テンプレートの絶対パス}` を読み込む
> 2. Read で `{対象 instruction ファイルの絶対パス}` を読み込む
> 3. テンプレートの指示に従い、以下の各項目について照合を実行する
> 4. 結果テーブルのみを返答する
>
> 照合対象の項目:
> {該当する .med.md 項目をここに展開}
>
> パス変数:
> - comparison_template: `{comparison テンプレートの絶対パス}`
> - instruction_file: `{対象 instruction ファイルの絶対パス}`

#### Step 3: 結果サマリの表示

サブエージェントの返答を集約し、テキスト出力:
```
## Phase 2: 照合完了
- new（追記可能）: {N}件
- duplicate（重複）: {N}件
- contradiction（矛盾）: {N}件
- conditional（条件付き共存）: {N}件
- strengthening（補強）: {N}件
```

---

### Phase 3: 反映

CLAUDE.md の per-item approval ルールに従い、各項目を**個別に**ユーザー承認する。
AskUserQuestion は使わず、各項目をテキスト出力してユーザーの応答を待つ。

#### new / conditional 項目

項目ごとに以下をテキスト出力:

```
### [{N}/{total}] {KE-ID}: {タイトル} → {対象ファイル名}に追記

判定: {new or conditional}

追記内容:
## {指示タイトル}

- **scope**: {scope}
- **action**: {action}
- **rationale**: {rationale}
- **conditions**: {conditions}
- **source**: {source_path}
```

ユーザーが承認したら `.claude/instructions/{対象ファイル}` に Edit で追記する。

#### strengthening 項目

項目ごとに以下をテキスト出力:

```
### [{N}/{total}] {KE-ID}: {タイトル} → {対象ファイル名}の既存項目を補強

既存:
{既存の該当箇所を引用}

補強内容:
- rationale に追加: {新たなデータ・根拠}
```

ユーザーが承認したら既存項目の rationale を Edit で更新する。

#### duplicate 項目

項目ごとに以下をテキスト出力:

```
### [{N}/{total}] {KE-ID}: {タイトル} → 重複のためスキップ

重複先: {対象ファイル名} > {既存の該当セクション名}
```

ユーザーが `docs/knowledge/` 側の整理を指示した場合はそれに従う。

#### contradiction 項目

項目ごとに以下をテキスト出力:

```
### [{N}/{total}] {KE-ID}: {タイトル} → 矛盾を検知

新しい指示:
- scope: {scope}
- action: {action}
- rationale: {rationale}

既存の指示（{対象ファイル名}）:
{既存の該当箇所を引用}

選択肢:
1. 既存を維持（新しい指示を破棄）
2. 新しい方を採用（既存を更新）
3. 条件付き共存（scope/conditions を明確化して両方記載）
4. 要整理（docs/knowledge/ の対象ファイルの整理方針を出力）
```

ユーザーの選択に従って処理する。

#### 完了出力

全項目の処理後にテキスト出力:

```
## /instruction_extract 完了
- 追加: {N}件 → {対象ファイル一覧}
- 重複スキップ: {N}件
- 矛盾解決: {N}件
```
