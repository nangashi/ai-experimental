# skill_design 詳細設計書

## 概要

要件と評価基準をもとに、スキルのワークフロー案を生成・比較・議論し、詳細設計書（design-spec.md）を作成するスキル。

- **コマンド**: `/skill_design {skill_name}`
- **入力**: `{work_dir}/requirements.md`, `{work_dir}/evaluation.md`
- **出力**: `{work_dir}/design-spec.md`

## 前提条件

- `{work_dir}/requirements.md` が存在すること
- `{work_dir}/evaluation.md` が存在すること
- 不在の場合: 「先に `/skill_require {skill_name}` を実行してください」と出力して終了

---

## ワークフロー

Phase 0（入力検証）→ 1（案出し）→ 2（人間選定）→ 3（攻撃者議論）→ 4（詳細設計書生成）

### Phase 0: 入力検証

**目的**: 前提ファイルを検証する

#### Step 1: 入力検証

`{work_dir}/requirements.md` と `{work_dir}/evaluation.md` の存在を確認する。

### Phase 1: 案出し

**目的**: AI が3案を生成する。うち少なくとも1案は根本的に異なるアプローチとする

**出典**: design.md Phase 1

#### Step 1: 候補生成（サブエージェントに委譲）

Task（sonnet）で候補生成サブエージェントを起動:

```
`{skill_dir}/templates/generate-candidates.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
```

サブエージェントの入力:
- `{work_dir}/requirements.md`
- `{work_dir}/evaluation.md`

サブエージェントの出力:
- `{work_dir}/work/candidates-raw.md` に3案を保存
- 件数サマリーを返す

#### Step 2: ユーザーへの提示

`{work_dir}/work/candidates-raw.md` を Read し、各案の概要をユーザーに提示する:

```
### 案A: {名前}
{概要・アプローチ}

### 案B: {名前}
{概要・アプローチ}

### 案C: {名前}
{概要・アプローチ}
※ この案は他の案と {差異の説明} の点で根本的に異なります
```

### Phase 2: 人間による選定

**目的**: 人間が案を絞り込む

**出典**: design.md Phase 2

AskUserQuestion で2案を選定させる:
- 選択肢: 案A, 案B, 案C（multiSelect: true, 2件選択を求める）

### Phase 3: 攻撃者議論＋判定

**目的**: 各案の弱点を攻撃者ロールが洗い出し、判定者が統合・推奨を出す

**出典**: design.md Phase 3、設計判断 D4

#### Step 1: 攻撃者（並列実行）

2つの Task（sonnet）を並列に起動する:

```
`{skill_dir}/templates/attacker.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
- {target_candidate}: {selected_1 or selected_2}
- {evaluation_path}: {work_dir}/evaluation.md
- {candidates_path}: {work_dir}/work/candidates-raw.md
- {output_path}: {work_dir}/work/attacker-{1 or 2}.md
```

各サブエージェントは攻撃結果をファイルに保存し、件数サマリーを返す。

#### Step 2: 擁護者（並列実行）

攻撃者完了後、2つの Task（sonnet）を並列に起動する:

```
`{skill_dir}/templates/defender.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
- {target_candidate}: {selected_1 or selected_2}
- {attack_path}: {work_dir}/work/attacker-{1 or 2}.md
- {candidates_path}: {work_dir}/work/candidates-raw.md
- {output_path}: {work_dir}/work/defender-{1 or 2}.md
```

#### Step 3: 判定者

全ロール完了後、Task（sonnet）を起動する:

```
`{skill_dir}/templates/judge.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
- {attacker_1_path}: {work_dir}/work/attacker-1.md
- {defender_1_path}: {work_dir}/work/defender-1.md
- {attacker_2_path}: {work_dir}/work/attacker-2.md
- {defender_2_path}: {work_dir}/work/defender-2.md
- {evaluation_path}: {work_dir}/evaluation.md
- {output_path}: {work_dir}/work/judge.md
```

判定者は以下を出力する:
1. 各案の「防御しきれなかった弱点」の整理
2. 統合案の検討
3. 推奨の明示（A案/B案/統合案）と理由
4. 実装方針の指針

#### Step 4: 実行順の最適化 — D4

```
[攻撃者1, 攻撃者2] → 並列
[擁護者1, 擁護者2] → 並列（各攻撃者完了後）
[判定者] → シーケンシャル（全ロール完了後）
```

**D4 の根拠**: 攻撃者1/2 は互いに独立のため並列実行可能。擁護者は対応する攻撃者の出力に依存。判定者は全ロールの出力に依存。各ロールの出力はファイル経由で受け渡し（親コンテキスト中継パターンを回避）。

#### Step 5: 結果のユーザー提示

判定者の出力をユーザーに提示し、推奨に同意するか確認する。

### Phase 4: 詳細設計書の生成

**目的**: 選定案をもとに、skill_implement が消費する詳細設計書（design-spec.md）を生成する

**新規追加**

#### Step 1: 設計書生成（サブエージェントに委譲）

Task（sonnet）で設計書生成サブエージェントを起動:

```
`{skill_dir}/templates/generate-design-spec.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
- {requirements_path}: {work_dir}/requirements.md
- {evaluation_path}: {work_dir}/evaluation.md
- {judge_path}: {work_dir}/work/judge.md
- {candidates_path}: {work_dir}/work/candidates-raw.md
- {selected_candidate}: {選定案ID}
- {output_path}: {work_dir}/design-spec.md
```

サブエージェントは design-spec.md スキーマ（overview.md 参照）に従った設計書を生成する。

#### Step 2: 整合性チェック

生成された design-spec.md に対して以下を検証する:

1. **evaluation.md との整合性**: 各評価基準（E-{N}）に対応するエビデンスが出力構造設計のマッピングに定義されているか
2. **requirements.md との整合性**: 要件の全要素が設計書のいずれかの Phase でカバーされているか
3. **内部整合性**: サブエージェント定義の入出力がワークフローのデータフローと一致しているか

不整合がある場合は修正して再生成する。

#### Step 3: ユーザー確認

設計書の概要をユーザーに提示し、承認を得る:

```
### 設計書サマリ
- ワークフロー: {Phase数} Phase
- サブエージェント: {数}個（並列: {数}、シーケンシャル: {数}）
- ファイル構成: SKILL.md + references/{N}ファイル + templates/{M}ファイル
- 人間関与: {数}ポイント

設計書の全文: {work_dir}/design-spec.md

修正があればお知らせください。問題なければ「ok」と回答してください。
```

### 完了出力

```
## skill_design 完了
- 要件定義: {work_dir}/requirements.md
- 評価基準: {work_dir}/evaluation.md
- 詳細設計書: {work_dir}/design-spec.md

次のステップ: `/skill_implement {skill_name}` で実装に進んでください。
```

---

## ファイル構成

```
.claude/skills/skill_design/
  SKILL.md                       # /skill_design コマンド定義
  references/
    output-schemas.md            # design-spec.md のスキーマ定義（overview.md から抜粋）
  templates/
    generate-candidates.md       # Phase 1: 案出しサブエージェント指示
    attacker.md                  # Phase 3: 攻撃者ロール指示
    defender.md                  # Phase 3: 擁護者ロール指示
    judge.md                     # Phase 3: 判定者ロール指示
    generate-design-spec.md      # Phase 4: 設計書生成サブエージェント指示
```

## サブエージェント構成

| ID | Phase | モデル | 入力ファイル | 出力ファイル | 並列化 |
|----|-------|--------|------------|------------|--------|
| SA-1 | Phase 1 | sonnet | requirements.md, evaluation.md | work/candidates-raw.md | 単独 |
| SA-2a | Phase 3 | sonnet | evaluation.md, candidates-raw.md | work/attacker-1.md | SA-2b と並列 |
| SA-2b | Phase 3 | sonnet | evaluation.md, candidates-raw.md | work/attacker-2.md | SA-2a と並列 |
| SA-3a | Phase 3 | sonnet | candidates-raw.md, attacker-1.md | work/defender-1.md | SA-3b と並列 |
| SA-3b | Phase 3 | sonnet | candidates-raw.md, attacker-2.md | work/defender-2.md | SA-3a と並列 |
| SA-4 | Phase 3 | sonnet | attacker-{1,2}.md, defender-{1,2}.md, evaluation.md | work/judge.md | 単独 |
| SA-5 | Phase 4 | sonnet | requirements.md, evaluation.md, candidates-raw.md, judge.md | design-spec.md | 単独 |

## 人間関与ポイント

| タイミング | 関与内容 | 必須/任意 |
|-----------|---------|----------|
| Phase 1 Step 2 | 案の確認 | 参考（選定は Phase 2） |
| Phase 2 | 案の選定（2案） | 必須 |
| Phase 3 Step 5 | 攻撃者議論の結果確認・推奨への同意 | 必須 |
| Phase 4 Step 3 | 設計書の承認 | 必須 |

## エラーハンドリング

| エラー種別 | 検出方法 | 対応 |
|-----------|---------|------|
| 前提ファイル不在 | Phase 0 Step 1 | `/skill_require` の実行を案内して終了 |
| サブエージェント失敗 | Task 結果のエラー判定 | AskUserQuestion で「リトライ/中止」。リトライ1回のみ |
| 整合性チェック不合格 | Phase 4 Step 2 | 不整合箇所を特定し、サブエージェントで再生成 |
