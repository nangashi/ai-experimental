---
allowed-tools: Bash, Glob, Grep, Read, Write, Edit, Task, AskUserQuestion
description: 技術的な意思決定をPrOACTフレームワークに基づく構造化審議で行い、ADRを生成するスキル
disable-model-invocation: true
---

技術選定・アーキテクチャ設計・開発方針策定など、トレードオフを伴う意思決定において、構造化された審議プロセスを実行し、ADR（Architecture Decision Record）を生成する。

## 使い方

```
/adr_create
```

引数なし。対話形式で議題と実行レベルを収集する。

## コンテキスト節約の原則

1. 参照ファイルは使用するPhaseでのみ読み込む（先読みしない）
2. 大量コンテンツの生成はサブエージェントに委譲する
3. サブエージェントからの返答は最小限にする（詳細はファイルに保存させる）
4. 親コンテキストには要約・メタデータのみ保持する
5. サブエージェント間のデータ受け渡しはファイル経由で行う（親を中継しない）

## 実行レベル

| レベル | 名称 | 実行フェーズ | 用途 |
|--------|------|------------|------|
| Level 1 | 軽量 | 0 → 2 → 4 → 7 → 8 | ユーザーが代替案を提供。CSD/選択肢生成/プレモーテム/連鎖分析スキップ |
| Level 2 | 標準 | 0 → 1 → 2 → 3+4 → 7 → 8 | 標準的な意思決定プロセス |
| Level 3 | 完全 | 0 → 1 → 2 → 3+4 → 5 → 6 → 7 → 8 | 完全な審議（リスク分析+将来影響分析を含む） |

## パス変数

- `{skill_dir}`: このファイルが存在するディレクトリの絶対パス
- `{topic_slug}`: Phase 0 で生成する英数字+ハイフンのスラッグ（30文字以内）
- `{work_dir}`: `.skill_output/adr_create/{topic_slug}/` の絶対パス（プロジェクトルートからの相対）
- `{adr_dir}`: `docs/adr` の絶対パス（プロジェクトルートからの相対）

## ワークフロー

Phase 0 で議題と実行レベルを確定し、Level に応じて Phase 1-6 を順次実行する。
Phase 7 で審議結果をユーザーに提示し、ユーザーの決定後 Phase 8 で ADR を生成する。

---

### Phase 0: 初期化・決定ステートメント策定

```
## Phase 0: 初期化
```

#### Step 1: 議題収集

ユーザーに以下を質問し、応答を待つ:
「どのような技術的意思決定について審議しますか？背景や制約があれば合わせて教えてください。」

#### Step 2: 実行レベル選択

`AskUserQuestion` で実行レベルを選択させる:
- Level 1（軽量）: 代替案が明確で、トレードオフの整理のみ必要な場合
- Level 2（標準）: 制約の確認と代替案の探索も含めた標準的な審議
- Level 3（完全）: リスク分析と将来影響分析を含む完全な審議

`{level}` を記録する。

#### Step 3: Level 1 の場合 — 代替案収集

`{level}` == 1 の場合のみ:
ユーザーに以下を質問し、応答を待つ:
「検討する代替案を2-5件リストしてください。」

#### Step 4: 作業ディレクトリ作成

1. 議題から `{topic_slug}` を生成する（英数字+ハイフン、30文字以内。日本語はローマ字化）
2. `Bash`: `mkdir -p {work_dir}`

#### Step 5: 決定ステートメント策定

ユーザーの議題テキストから、以下を親エージェントがインラインで処理する:

1. 議題を「〜としてどの方式/技術/方針を採用するか」の形式に変換する
2. スコープを定義する: 何が決定対象で、何が対象外かを明確にする
3. 可逆性を評価する: この決定を後から変更するコストはどの程度か（high/medium/low）

output-schemas.md の decision-statement.md フォーマットに従い、`{work_dir}/decision-statement.md` に Write で保存する。

#### Step 6: ユーザー確認

決定ステートメントの内容をユーザーに提示し、応答を待つ:
「修正があればお知らせください。問題なければ『ok』と回答してください。」
- 承認（ok等）: 次のフェーズへ
- 修正指示あり: 修正を反映して Step 5 を再実行

#### Step 7: Level 1 の代替案保存

`{level}` == 1 の場合: Step 3 で収集した代替案を `{work_dir}/alternatives.md` に保存する。
output-schemas.md の alternatives.md フォーマットに準拠する。提案元は「ユーザー提供」とする。

#### Step 8: リサーチ

Task（sonnet）でリサーチャーサブエージェントを起動:

```
`{skill_dir}/references/phase-specifications.md` の「Research」セクションを Read で読み込み、
`{skill_dir}/references/agent-prompts.md` の「Researcher」セクションを Read で読み込み、
その内容に従って処理を実行してください。

パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
```

サブエージェントは `{work_dir}/research.md` に保存し、件数サマリーを返す。

#### Step 9: 既存ADR参照

1. Glob で `{adr_dir}/[0-9][0-9][0-9][0-9]-*.md` を検索
2. ファイルが存在しない場合: スキップ。`{has_prior_decisions}` = false を記録
3. ファイルが存在する場合:
   - Task（sonnet）で既存ADR抽出サブエージェントを起動:

```
`{skill_dir}/references/phase-specifications.md` の「Prior Decisions Extraction」セクションを Read で読み込み、
その内容に従って処理を実行してください。

パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
- {adr_dir}: {値}
```

   - サブエージェントは `{work_dir}/prior-decisions.md` に保存し、件数サマリーを返す
   - `{has_prior_decisions}` = true を記録

```
## Phase 0 完了
- 議題: {topic の要約}
- 実行レベル: Level {level}
- 作業ディレクトリ: {work_dir}
- リサーチ: {N}件の調査結果
- 既存ADR: {N}件（関連: {M}件）※ 既存ADRがない場合は「なし」
```

**次フェーズ**: `{level}` == 1 → Phase 2 へ、それ以外 → Phase 1 へ

---

### Phase 1: CSD分類

**スキップ条件**: `{level}` == 1

```
## Phase 1: CSD分類
```

#### Step 1: 制約収集

Task（sonnet）でファシリテーターサブエージェントを起動:

```
`{skill_dir}/references/phase-specifications.md` の「Phase 1 前半」セクションを Read で読み込み、
その内容に従って処理を実行してください。

パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
```

サブエージェントは `{work_dir}/csd-draft.md` に保存し、件数サマリーを返す。

#### Step 2: レッドチーム検証

Task（sonnet）でレッドチームサブエージェントを起動:

```
`{skill_dir}/references/phase-specifications.md` の「Phase 1 後半」セクションを Read で読み込み、
`{skill_dir}/references/agent-prompts.md` の「Red Team」セクションを Read で読み込み、
その内容に従って処理を実行してください。

パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
```

サブエージェントは `{work_dir}/csd-challenges.md` に保存し、件数サマリーを返す。

#### Step 3: CSD統合

1. `{work_dir}/csd-draft.md` と `{work_dir}/csd-challenges.md` を Read で読み込む
2. レッドチームの再分類提案を反映して `{work_dir}/csd-final.md` を Write で保存する

#### Step 4: ユーザー確認

CSD分類の結果をユーザーに提示し、応答を待つ:
- 確実: {N}件、仮定: {N}件、不確実: {N}件
- レッドチームからの再分類提案があった場合はその内容も提示
「修正があればお知らせください。問題なければ『ok』と回答してください。」
- 承認（ok等）: 次のフェーズへ
- 修正指示あり: 修正を反映して csd-final.md を更新

```
## Phase 1 完了
- 確実: {N}件, 仮定: {N}件, 不確実: {N}件
- レッドチーム再分類: {N}件
```

---

### Phase 2: 目的（Objectives）定義

```
## Phase 2: 目的定義
```

#### Step 1: 目的生成

Task（sonnet）でファシリテーターサブエージェントを起動:

```
`{skill_dir}/references/phase-specifications.md` の「Phase 2」セクションを Read で読み込み、
その内容に従って処理を実行してください。

パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
```

サブエージェントは `{work_dir}/objectives.md` に保存し、目的の一覧を返す。

#### Step 2: ユーザー確認

目的の一覧をユーザーに提示し、応答を待つ:
- 各目的の名称と定義を表示
「追加・削除・修正があればお知らせください。問題なければ『ok』と回答してください。」
- 承認（ok等）: 次のフェーズへ
- 修正指示あり: 追加/削除/修正を反映。ただし5件上限を維持。5件を超える場合はユーザーに優先順位付けを依頼

`{objective_count}` を記録する（Phase 3+4 のエージェント数を決定）。

```
## Phase 2 完了
- 判断基準: {objective_count}件
- {OBJ-1 名前}, {OBJ-2 名前}, ...
```

**次フェーズ**: `{level}` == 1 → Phase 4（評価のみ）へ、それ以外 → Phase 3+4 へ

---

### Phase 3+4: 代替案生成・評価

**スキップ条件**: `{level}` == 1（代わりに Phase 4 評価のみを実行）

```
## Phase 3+4: 代替案生成・評価
```

#### Step 1: 並列評価

`{objective_count}` 個の Task（sonnet）を**1つのメッセージで並列に**起動する。

各サブエージェントへの指示:

```
`{skill_dir}/references/phase-specifications.md` の「Phase 3+4」セクションを Read で読み込み、
`{skill_dir}/references/agent-prompts.md` の「Objective Evaluator」セクションを Read で読み込み、
その内容に従って処理を実行してください。

パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
- {objective_id}: OBJ-{N}
- {evaluation_save_path}: {work_dir}/eval-obj-{N}.md の絶対パス
```

全サブエージェントの完了を待つ。

#### Step 2: 代替案統合

1. `{work_dir}/eval-obj-*.md` を全て Read で読み込む
2. 提案された代替案を統合・重複排除する
3. 統合結果を `{work_dir}/alternatives.md` に Write で保存する

#### Step 3: 評価マトリクス統合

1. 各 eval-obj-{N}.md の評価結果を統合する
2. alternatives.md の代替案 × objectives.md の目的 のマトリクスを構成する
3. `{work_dir}/evaluation-matrix.md` に Write で保存する

```
## Phase 3+4 完了
- 評価エージェント: {objective_count}件
- 検出された代替案: {N}件
```

Phase 5 へ（Level 3）または Phase 7 へ（Level 2）

---

### Phase 4: 評価のみ（Level 1）

**実行条件**: `{level}` == 1

```
## Phase 4: 評価（Level 1）
```

Phase 3+4 の Step 1 と同様だが、サブエージェントへの指示で Phase 3+4 の代わりに「Phase 4（Level 1）」セクションを参照させる。

```
`{skill_dir}/references/phase-specifications.md` の「Phase 4: 評価のみ」セクションを Read で読み込み、
`{skill_dir}/references/agent-prompts.md` の「Objective Evaluator」セクションを Read で読み込み、
その内容に従って処理を実行してください。

パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
- {objective_id}: OBJ-{N}
- {evaluation_save_path}: {work_dir}/eval-obj-{N}.md の絶対パス
```

全サブエージェント完了後、Phase 3+4 の Step 3 と同じ方法で evaluation-matrix.md を生成する。

```
## Phase 4 完了（Level 1）
- 評価エージェント: {objective_count}件
- 評価した代替案: {N}件
```

Phase 7 へ

---

### Phase 5: プレモーテム分析

**スキップ条件**: `{level}` != 3

```
## Phase 5: プレモーテム分析
```

Task（sonnet）でプレモーテムアナリストを起動:

```
`{skill_dir}/references/phase-specifications.md` の「Phase 5」セクションを Read で読み込み、
`{skill_dir}/references/agent-prompts.md` の「Premortem Analyst」セクションを Read で読み込み、
その内容に従って処理を実行してください。

パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
```

サブエージェントは `{work_dir}/premortem.md` に保存し、件数サマリーを返す。

```
## Phase 5 完了
- 分析対象: {N}件の選択肢
- 失敗シナリオ: 計{M}件
```

---

### Phase 6: 連鎖する意思決定の検証

**スキップ条件**: `{level}` != 3

```
## Phase 6: 連鎖する意思決定
```

Task（sonnet）で将来分析エージェントを起動:

```
`{skill_dir}/references/phase-specifications.md` の「Phase 6」セクションを Read で読み込み、
`{skill_dir}/references/agent-prompts.md` の「Future Analyst」セクションを Read で読み込み、
その内容に従って処理を実行してください。

パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
```

サブエージェントは `{work_dir}/linked-decisions.md` に保存し、件数サマリーを返す。

```
## Phase 6 完了
- 将来の決定ポイント: {N}件
```

---

### Phase 7: 統合・整理 → 人間に提示

```
## Phase 7: 審議結果
```

#### Step 1: 審議サマリー生成

Task（sonnet）でファシリテーターサブエージェントを起動:

```
`{skill_dir}/references/phase-specifications.md` の「Phase 7」セクションを Read で読み込み、
その内容に従って処理を実行してください。

パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
- {level}: {値}
```

サブエージェントは `{work_dir}/deliberation-summary.md` に保存し、件数サマリーを返す。

#### Step 2: ユーザーに審議結果を提示

`{work_dir}/deliberation-summary.md` の内容をユーザーに出力する。

#### Step 3: ユーザーの決定を収集

`AskUserQuestion` で採用する選択肢を質問する:
- alternatives.md の代替案を選択肢として提示
- ユーザーが選択肢を選ぶ

`{selected_alternative}` を記録する。

#### Step 4: 根拠とトレードオフの収集

ユーザーに以下を質問し、応答を待つ:
「選択の根拠を教えてください。どの判断基準を重視しましたか？また、受け入れるトレードオフは何ですか？」

`{user_rationale}` と `{accepted_tradeoffs}` を記録する（回答から分離。分離が難しい場合は両方に同内容を設定）。

---

### Phase 8: ADR生成

```
## Phase 8: ADR生成
```

#### Step 1: ADR番号解決

1. `Bash`: `mkdir -p {adr_dir}`
2. Glob で `{adr_dir}/[0-9][0-9][0-9][0-9]-*.md` を検索
3. 既存ファイルの最大番号 + 1 で新番号を決定する。ファイルが存在しなければ 0001
4. 決定ステートメントから `{title_slug}` を生成する（英語、小文字、ハイフン区切り、50文字以内）
5. `{adr_path}` = `{adr_dir}/{NNNN}-{title_slug}.md`

#### Step 2: ADR生成

Task（sonnet）でADR生成サブエージェントを起動:

```
`{skill_dir}/references/phase-specifications.md` の「Phase 8」セクションを Read で読み込み、
`{skill_dir}/references/output-schemas.md` の「ADRテンプレート」セクションを Read で読み込み、
`{skill_dir}/references/agent-prompts.md` の「ADR Generator」セクションを Read で読み込み、
その内容に従って処理を実行してください。

パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
- {adr_path}: {値}
- {adr_number}: {NNNN}
- {selected_alternative}: {値}
- {user_rationale}: {値}
- {accepted_tradeoffs}: {値}
- {level}: {値}
```

サブエージェントは `{adr_path}` に ADR を Write で保存する。

#### Step 3: 完了

```
## adr_create 完了
- 議題: {topic の要約}
- 実行レベル: Level {level}
- 判断基準: {objective_count}件
- 検討した選択肢: {alternative_count}件
- 採用: {selected_alternative}
- ADR: {adr_path}
- 作業ディレクトリ: {work_dir}
```

---

## エラーハンドリング

- **サブエージェント失敗**: エラー内容をユーザーに提示し、`AskUserQuestion` で「リトライ」/「中止」を選択させる。リトライは1回のみ。2回目の失敗でスキル終了
- **目的5件超過**: ユーザーに優先順位付けを依頼し、上位5件に絞る
- **代替案が2件未満**: ユーザーに追加の代替案を提供するよう依頼する
