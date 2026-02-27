# skill_implement 詳細設計書

## 概要

詳細設計書（design-spec.md）に基づき、スキルの各ファイルを生成・デプロイ・検証するスキル。

- **コマンド**: `/skill_implement {skill_name}`
- **入力**: `{work_dir}/design-spec.md`
- **出力**: `.claude/skills/{skill_name}/` ディレクトリ一式

## 前提条件

- `{work_dir}/design-spec.md` が存在すること
- 不在の場合: 「先に `/skill_design {skill_name}` を実行してください」と出力して終了
- `{target_skill_dir}` に既存スキルがある場合、上書き確認する

---

## ワークフロー

Phase 0（入力検証）→ 1（SKILL.md 生成）→ 2+3（テンプレート生成 ‖ リファレンス生成）→ 4（デプロイ）→ 5（構造検証）

### Phase 0: 入力検証

**目的**: 前提ファイルの存在を確認し、デプロイ先を準備する

#### Step 1: ファイル検証

以下のファイルの存在を確認する:
- `{work_dir}/design-spec.md`

#### Step 2: デプロイ先の確認

`{target_skill_dir}` = `.claude/skills/{skill_name}/` を決定する。

既存ディレクトリがある場合、AskUserQuestion で以下を確認:
- **上書き**: 既存ファイルを上書きして生成
- **中止**: スキルを終了

### Phase 1: SKILL.md 生成

**目的**: design-spec.md のワークフロー定義をもとに、スキルの本体である SKILL.md を生成する

**出典**: design.md Phase 4（拡張）

#### Step 1: SKILL.md 生成（サブエージェントに委譲）

Task（sonnet）で SKILL.md 生成サブエージェントを起動:

```
`{skill_dir}/templates/generate-skill-md.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
- {design_spec_path}: {work_dir}/design-spec.md
- {output_path}: {work_dir}/work/skill-md-draft.md
```

サブエージェントは design-spec.md の以下の要素を SKILL.md に変換する:
- ワークフロー → SKILL.md の Phase 定義
- サブエージェント定義 → テンプレート呼び出し指示
- 人間関与ポイント → AskUserQuestion / ユーザー確認ステップ
- エラーハンドリング → エラー処理フロー

出力: `{work_dir}/work/skill-md-draft.md`

#### Step 2: ユーザー確認

生成された SKILL.md のドラフトを Read してユーザーに提示する。修正指示があれば反映する。

### Phase 2: テンプレート生成

**目的**: design-spec.md のサブエージェント定義をもとに、各テンプレートファイルを生成する

#### Step 1: テンプレート一覧の抽出

design-spec.md のサブエージェント定義テーブルとファイル構成から、生成すべきテンプレート一覧を抽出する。

#### Step 2: テンプレート生成（並列、サブエージェントに委譲）

各テンプレートについて Task（sonnet）を並列に起動:

```
`{skill_dir}/templates/generate-template.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
- {design_spec_path}: {work_dir}/design-spec.md
- {template_name}: {テンプレート名}
- {subagent_id}: {対応するサブエージェントID}
- {output_path}: {work_dir}/work/template-{template_name}.md
```

各サブエージェントは以下を含むテンプレートを生成する:
- サブエージェントの役割と目的
- 入力ファイルの読み込み指示
- 処理手順
- 出力フォーマットと保存先
- 返答形式（件数サマリー等）

### Phase 3: リファレンス生成

**目的**: design-spec.md で定義された参照ファイル（スキーマ定義、ルーブリック等）を生成する

#### Step 1: リファレンス一覧の抽出

design-spec.md のファイル構成から、生成すべきリファレンス一覧を抽出する。

#### Step 2: リファレンス生成（並列、サブエージェントに委譲）

各リファレンスについて Task（sonnet）を並列に起動:

```
`{skill_dir}/templates/generate-reference.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
- {design_spec_path}: {work_dir}/design-spec.md
- {reference_name}: {リファレンス名}
- {output_path}: {work_dir}/work/reference-{reference_name}.md
```

### Phase 4: デプロイ

**目的**: 生成されたファイルをスキルディレクトリに配置する

#### Step 1: ユーザー確認

生成されたファイル一覧と配置先をユーザーに提示する:

```
### デプロイ対象
{target_skill_dir}/
  SKILL.md
  templates/
    {template_1}.md
    {template_2}.md
  references/
    {reference_1}.md

デプロイしてよろしいですか？
```

#### Step 2: ファイル配置

承認後、以下の順でファイルを配置する:

1. `{target_skill_dir}/` ディレクトリを作成
2. `{target_skill_dir}/templates/` ディレクトリを作成
3. `{target_skill_dir}/references/` ディレクトリを作成
4. 各ファイルを `{work_dir}/work/` から `{target_skill_dir}/` にコピー（Write）

### Phase 5: 構造検証

**目的**: デプロイ後のファイル整合性を検証する

**新規追加**

#### Step 1: ファイル存在チェック

design-spec.md のファイル構成で定義された全ファイルが `{target_skill_dir}/` に存在することを確認する。

#### Step 2: 内部参照チェック

SKILL.md 内のテンプレートパス参照（`{skill_dir}/templates/*.md`）が、実際に存在するファイルと一致することを確認する。

#### Step 3: 検証結果の提示

```
### 構造検証結果
- ファイル存在: {OK/NG}（{N}/{M} ファイル）
- 内部参照: {OK/NG}（{N}/{M} 参照）

{NG がある場合、不整合の詳細を列挙}
```

NG がある場合、修正を実行する。

### 完了出力

```
## skill_implement 完了
- スキルディレクトリ: {target_skill_dir}/
- ファイル数: SKILL.md + templates/{N} + references/{M}
- 構造検証: {OK/NG}

次のステップ: `/skill_evaluate {skill_name}` で評価・改善に進んでください。
```

---

## ファイル構成

```
.claude/skills/skill_implement/
  SKILL.md                       # /skill_implement コマンド定義
  templates/
    generate-skill-md.md         # Phase 1: SKILL.md 生成サブエージェント指示
    generate-template.md         # Phase 2: テンプレート生成サブエージェント指示
    generate-reference.md        # Phase 3: リファレンス生成サブエージェント指示
```

## サブエージェント構成

| ID | Phase | モデル | 入力ファイル | 出力ファイル | 並列化 |
|----|-------|--------|------------|------------|--------|
| SA-1 | Phase 1 | sonnet | design-spec.md | work/skill-md-draft.md | 単独 |
| SA-2a..N | Phase 2 | sonnet | design-spec.md | work/template-{name}.md | 全テンプレート並列 |
| SA-3a..M | Phase 3 | sonnet | design-spec.md | work/reference-{name}.md | 全リファレンス並列 |

**注意**: Phase 2 と Phase 3 のサブエージェント数は design-spec.md のファイル構成に依存する。Phase 2 と Phase 3 は互いに独立のため並列実行可能。

## 人間関与ポイント

| タイミング | 関与内容 | 必須/任意 |
|-----------|---------|----------|
| Phase 0 Step 2 | 既存スキルの上書き確認 | 条件付き必須 |
| Phase 1 Step 2 | SKILL.md ドラフトの確認 | 必須 |
| Phase 4 Step 1 | デプロイ前の確認 | 必須 |
| Phase 5 Step 3 | 構造検証結果の確認 | 参考 |

## エラーハンドリング

| エラー種別 | 検出方法 | 対応 |
|-----------|---------|------|
| 前提ファイル不在 | Phase 0 Step 1 | `/skill_design` の実行を案内して終了 |
| 既存スキルの上書き | Phase 0 Step 2 | AskUserQuestion で上書き/中止を確認 |
| サブエージェント失敗 | Task 結果のエラー判定 | AskUserQuestion で「リトライ/中止」。リトライ1回のみ |
| 構造検証 NG | Phase 5 Step 1-2 | 不整合箇所を特定し修正を実行 |
