# skill_evaluate 詳細設計書

## 概要

デプロイ済みスキルの実行記録を evaluation.md の評価基準でスコアリングし、失敗分析に基づく改善を実施するスキル。改善ループは行わず、データ蓄積後に単発実行する方式。

- **コマンド**: `/skill_evaluate {skill_name}`
- **入力**: `{work_dir}/evaluation.md`, `.claude/skills/{skill_name}/`（デプロイ済みスキル）, 実行記録ファイル群
- **出力**: `{work_dir}/test-results.md`, `{work_dir}/improvements.md`

## 前提条件

- `{work_dir}/evaluation.md` が存在すること
- `{target_skill_dir}/SKILL.md` が存在すること（デプロイ済み）
- スキルの実行記録が存在すること（実際の使用で生成された出力ファイル群）
- 不在の場合:
  - evaluation.md なし: 「先に `/skill_require {skill_name}` を実行してください」
  - SKILL.md なし: 「先に `/skill_implement {skill_name}` を実行してください」
  - 実行記録なし: 「スキルを実際に使用し、実行記録を蓄積してから再度実行してください」

---

## ワークフロー

Phase 0（入力検証）→ 1（実行記録収集）→ 2（評価・スコアリング）→ 3（失敗分析）→ 4（改善実装）

改善ループは実施しない。再評価が必要な場合は、スキルを実際に使用してデータを蓄積した後に `/skill_evaluate` を再実行する。

### Phase 0: 入力検証

**目的**: 前提ファイルの検証

#### Step 1: ファイル検証

以下のファイルの存在を確認する:
- `{work_dir}/evaluation.md`
- `{target_skill_dir}/SKILL.md`

#### Step 2: 状態提示

```
### skill_evaluate 開始
- 対象スキル: {skill_name}
- 評価基準: {N}項目
- テストケース: {M}件
```

### Phase 1: 実行記録収集

**目的**: スキルの実際の使用で生成された実行記録を収集・整理する

#### Step 1: 実行記録の特定

`{work_dir}/design-spec.md` の出力構造設計を参照し、対象スキルの出力ディレクトリ（`{output_dir}/runs/`）配下のサブディレクトリを一覧する。実行記録の一覧をユーザーに提示し、評価対象を選択させる。

design-spec.md が存在しない場合（「評価のみ」パス）は、ユーザーに実行記録のパスを直接指定させる。

#### Step 2: 実行記録の読み込みと整理

指定された実行記録を Read で読み込み、evaluation.md のテストケースとの対応付けを行う:
- 各実行記録がどのテストケース（TC-{N}）の条件に該当するかを判定する
- 対応付けの結果をユーザーに提示し確認する

#### Step 3: 実行記録の保存

対応付けた実行記録を `{work_dir}/work/record-tc{N}.md` として保存する。

### Phase 2: 評価・スコアリング

**目的**: 実行記録を評価基準に沿ってスコアリングする

**出典**: design.md Phase 5 Step 2-4

#### Step 1: 評価（並列、サブエージェントに委譲）

各実行記録について Task（sonnet）を並列に起動:

```
`{skill_dir}/templates/evaluate-output.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
- {evaluation_path}: {work_dir}/evaluation.md
- {record_path}: {work_dir}/work/record-tc{N}.md
- {test_case_id}: TC-{N}
- {output_path}: {work_dir}/work/eval-tc{N}.md
```

#### Step 2: 結果集約

各評価結果を集約して `{work_dir}/test-results.md` に Write で保存する。

集約内容:
- テストケースごとの各基準スコア
- 最低品質ライン達成/未達の判定
- 全体スコアのサマリー

#### Step 3: 人間によるスコアリング校正

テスト結果をユーザーに提示し、スコアリングの妥当性を確認する:

```
### 評価結果

| TC | E-1 | E-2 | E-3 | ... | 総合 |
|----|-----|-----|-----|-----|------|
| TC-01 | 4/5 | 3/5 | 5/5 | ... | 4.0 |
| TC-02 | 2/5 | 4/5 | 3/5 | ... | 3.0 |

最低品質ライン未達: {未達テストケースの一覧}

以下の点を確認してください:
1. スコアリングの甘辛は適切ですか？
2. 評価基準自体に追加・修正は必要ですか？
```

校正結果を反映して `test-results.md` と必要に応じて `evaluation.md` を更新する。

### Phase 3: 失敗分析

**目的**: 低評価テストケースの原因分析に基づく改善提案を出す

**出典**: design.md Phase 6

#### Step 1: 失敗判定

最低品質ライン未達のテストケースを抽出する。全テストケースが最低品質ラインを達成している場合、Phase 3 をスキップし完了出力に進む。

#### Step 2: 失敗分析（サブエージェントに委譲）

Task（sonnet）で失敗分析サブエージェントを起動:

```
`{skill_dir}/templates/analyze-failures.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
- {test_results_path}: {work_dir}/test-results.md
- {skill_path}: {target_skill_dir}/SKILL.md
- {evaluation_path}: {work_dir}/evaluation.md
- {output_path}: {work_dir}/improvements.md
```

サブエージェントは以下を出力する:
1. 低評価テストケースの実行記録と期待との差分
2. 差分の原因仮説
3. 原因仮説ごとの改善案
4. 各改善案を「微調整/再設計」に分類

#### Step 3: ユーザーへの提示

失敗分析結果をユーザーに提示し、改善に進むか確認する:

```
### 失敗分析結果
- 最低品質ライン未達: {N}件 / {M}件
- 改善案: {微調整 X件、再設計 Y件}

改善を実施しますか？
- **実施**: Phase 4（改善実装）に進みます
- **終了**: 現状のスキルを最終版とします
```

### Phase 4: 改善実装

**目的**: 失敗分析に基づく改善をスキルに適用する

#### Step 1: 改善方向性の選択

AskUserQuestion で採用する改善案を選択させる:
- 選択肢: improvements.md 内の各改善案
- multiSelect: true（複数選択可能）

#### Step 2: 改善内容の提示

選択された改善案の具体的な変更内容をユーザーに提示し、承認を得る。

#### Step 3: 改善実装（サブエージェントに委譲）

承認後、Task（sonnet）で改善実装サブエージェントを起動:

```
`{skill_dir}/templates/improve-skill.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
- {skill_path}: {target_skill_dir}/SKILL.md
- {improvement_path}: {work_dir}/improvements.md
- {selected_improvements}: {ユーザーが選択した改善案のID}
- {target_skill_dir}: {値}
```

サブエージェントは `{target_skill_dir}/` のファイルを更新する。

### 完了出力

```
## skill_evaluate 完了
- 対象スキル: {target_skill_dir}/
- 評価結果: {work_dir}/test-results.md
- スコアサマリ: {全基準の平均スコア}
- 最低品質ライン達成: {全達成/未達 N件}
{改善実施時: 改善案 {work_dir}/improvements.md}

次のステップ:
- スキルを使用してデータを蓄積し、再度 `/skill_evaluate {skill_name}` で再評価してください
- 完了の場合: スキルは {target_skill_dir}/ にデプロイ済みです
```

---

## ファイル構成

```
.claude/skills/skill_evaluate/
  SKILL.md                       # /skill_evaluate コマンド定義
  references/
    evaluation-rubric.md         # 評価ルーブリックのフォーマット定義
  templates/
    evaluate-output.md           # Phase 2: 評価サブエージェント指示
    analyze-failures.md          # Phase 3: 失敗分析サブエージェント指示
    improve-skill.md             # Phase 4: 改善実装サブエージェント指示
```

## サブエージェント構成

| ID | Phase | モデル | 入力ファイル | 出力ファイル | 並列化 |
|----|-------|--------|------------|------------|--------|
| SA-1a..N | Phase 2 | sonnet | evaluation.md, record-tc{N} | work/eval-tc{N}.md | 全TC並列 |
| SA-2 | Phase 3 | sonnet | test-results, SKILL.md, evaluation.md | improvements.md | 単独 |
| SA-3 | Phase 4 | sonnet | SKILL.md, improvements | {target_skill_dir}/ 更新 | 単独 |

**注意**: Phase 2 のサブエージェント数は実行記録の件数に依存する。

## 人間関与ポイント

| タイミング | 関与内容 | 必須/任意 |
|-----------|---------|----------|
| Phase 1 Step 1-2 | 実行記録の指定・対応付け確認 | 必須 |
| Phase 2 Step 3 | スコアリングの校正 | 必須 |
| Phase 3 Step 3 | 失敗分析結果の確認・改善実施判断 | 必須 |
| Phase 4 Step 1 | 改善方向性の選択 | 必須 |
| Phase 4 Step 2 | 改善内容の承認 | 必須 |

## エラーハンドリング

| エラー種別 | 検出方法 | 対応 |
|-----------|---------|------|
| 前提ファイル不在 | Phase 0 Step 1 | 対応する前提スキルの実行を案内して終了 |
| 実行記録不在 | Phase 1 Step 1 | スキルの実際の使用を案内して終了 |
| サブエージェント失敗 | Task 結果のエラー判定 | AskUserQuestion で「リトライ/中止」。リトライ1回のみ |
| 評価基準の不足 | Phase 2 でカバー外ケースを検出 | evaluation.md への追加を提案 |
