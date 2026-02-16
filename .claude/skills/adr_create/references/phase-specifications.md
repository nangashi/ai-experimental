# Phase Specifications

各サブエージェントは、自身が担当するフェーズのセクションのみを実行する。

---

## Research: 最新情報の調査

### 目的

決定ステートメントに関連する、時間経過で変化しうる事実を調査し、以降のフェーズが最新の情報に基づいて処理できるようにする。

### 入力

- `{work_dir}/decision-statement.md`
- `{skill_dir}/references/agent-prompts.md` の Researcher セクション

### 処理手順

1. agent-prompts.md の Researcher セクションの行動指針を確認する
2. 決定ステートメント（議題+スコープ）を読む
3. 「この決定に関わる事実のうち、時間経過で変化しうるものは何か？」を問い、調査すべき観点を特定する
4. 特定した観点ごとに検索クエリを生成する（計3〜5件）
5. 各クエリで `WebSearch` を実行する
6. 結果を構造化して保存する

### 出力フォーマット

`{work_dir}/research.md` に output-schemas.md の research.md フォーマットで保存する。

### 返答フォーマット

```
リサーチ完了: {N}件の観点を調査、{M}件の主要な知見を記録
```

---

## Prior Decisions Extraction: 既存ADRからの前提抽出

### 目的

`{adr_dir}` に存在する既存ADRから、今回の決定に関連する過去の決定事項を抽出し、以降のフェーズが既存の決定を前提として扱えるようにする。

### 入力

- `{work_dir}/decision-statement.md`
- `{adr_dir}/` 内の全ADRファイル

### 処理手順

1. 決定ステートメント（議題+スコープ）を読む
2. `{adr_dir}` 内の全ADRファイルを Read で読み込む
3. 各ADRについて、今回の議題との関連性を判断する:
   - 関連あり: 同じ技術領域、今回のスコープに影響する決定、今回の決定を制約する前提
   - 関連なし: 完全に異なる領域の決定
4. 関連するADRごとに以下を抽出する:
   - ADR番号とタイトル
   - 決定内容の要約
   - 今回の議題との関連の説明
   - 今回の決定で確実（Certainty）として扱うべき事項
5. 関連なしのADRも、番号・タイトル・関連なしの理由を簡潔に記録する

### 出力フォーマット

`{work_dir}/prior-decisions.md` に output-schemas.md の prior-decisions.md フォーマットで保存する。

### 返答フォーマット

```
既存ADR抽出完了: 全{N}件中、関連{M}件
```

---

## Phase 1: CSD分類

### 前半: 制約収集（Facilitator）

#### 目的

議題に関連する制約を収集し、確度で分類する。

#### 入力

- `{work_dir}/decision-statement.md`
- `{work_dir}/research.md`
- `{work_dir}/prior-decisions.md`（存在する場合）

#### 処理手順

1. prior-decisions.md が存在する場合、関連する既存決定を確実（Certainty）として取り込む。既存ADRで確定した事項は再検討の対象ではなく、今回の決定の前提として扱う
2. 決定ステートメントを読み、関連する制約を列挙する
   - 技術的制約（既存システム、言語、フレームワーク）
   - チーム制約（スキル、人数、経験）
   - ビジネス制約（予算、納期、コンプライアンス）
   - インフラ制約（クラウド、オンプレ、既存サービス）
3. 各制約をCSD（Certainty / Supposition / Doubt）に分類する
   - Certainty: 動かない事実。変更の余地がない
   - Supposition: 現時点では正しいと思われるが、変わりうる前提
   - Doubt: 不確実。情報不足で判断できない
4. 各制約に根拠・検証方法・影響範囲を付記する

#### 出力フォーマット

`{work_dir}/csd-draft.md` に output-schemas.md の csd-draft.md フォーマットで保存する。

#### 返答フォーマット

```
CSD分類完了: C={N}件, S={N}件, D={N}件
```

### 後半: レッドチーム検証

#### 目的

CSD分類の妥当性を批判的に検証する。

#### 入力

- `{work_dir}/csd-draft.md`
- `{skill_dir}/references/agent-prompts.md` の Red Team セクション

#### 処理手順

1. agent-prompts.md の Red Team セクションの行動指針に従う
2. csd-draft.md の全項目を検証する
3. 再分類が必要な項目、暗黙の仮定、検証不要な項目を記録する

#### 出力フォーマット

`{work_dir}/csd-challenges.md` に output-schemas.md の csd-challenges.md フォーマットで保存する。

#### 返答フォーマット

```
レッドチーム検証完了: 再分類提案={N}件, 暗黙の仮定検出={N}件
```

---

## Phase 2: 目的（Objectives）定義

### 目的

選択肢を評価するための判断基準を、選択肢を考える前に定義する。

### 入力

- `{work_dir}/decision-statement.md`
- `{work_dir}/csd-final.md`（Level 2/3 の場合のみ）

### 処理手順

1. 議題に関連する目的を列挙する（3-5件、最大5件を厳守）
2. 各目的について手段目的と根本目的を分離する
   - 手段目的の例: 「JWTを採用したい」「Redisを使いたくない」
   - 根本目的の例: 「ステートレスにスケールできること」「インフラ運用負荷を最小化したい」
   - 変換を行った場合は変換記録に残す
3. 各目的に測定方法（評価の視点）を定義する
4. 目的間の優先度は定義しない（人間の判断に委ねる）

### 出力フォーマット

`{work_dir}/objectives.md` に output-schemas.md の objectives.md フォーマットで保存する。

### 返答フォーマット

```
目的定義完了: {N}件
OBJ-1: {名前}
OBJ-2: {名前}
...
```

---

## Phase 3+4: 代替案生成・評価（Objective Evaluator）

### 目的

担当する判断基準（目的）の観点から、代替案を生成し評価する。

### 入力

- `{work_dir}/decision-statement.md`
- `{work_dir}/csd-final.md`（Level 2/3 の場合のみ）
- `{work_dir}/objectives.md`
- `{work_dir}/research.md`
- `{work_dir}/prior-decisions.md`（存在する場合）
- `{skill_dir}/references/agent-prompts.md` の Objective Evaluator セクション
- `{objective_id}`: 担当する目的の ID（例: OBJ-1）

### 処理手順

1. agent-prompts.md の Objective Evaluator セクションの行動指針を確認する
2. objectives.md から自分の担当目的（`{objective_id}`）の詳細を把握する
3. prior-decisions.md が存在する場合、既存決定との整合性を確認し、矛盾する代替案を提案しない
4. 他の目的も文脈として理解するが、評価は担当目的のみで行う

**代替案生成**（Level 2/3 のみ）:
4. 「この目的を最適化するなら、どのような選択肢があるか？」と考える
5. 2-4件の代替案を提案する。各案に「なぜこの目的に適しているか」を説明する

**評価**:
6. 全代替案（自分の提案 + 他のエージェントから来る可能性のある案）を担当目的の観点から評価する
   - 注: 他のエージェントの提案は、親エージェントが統合後に再評価を依頼する場合がある。初回実行では自分の提案のみ評価する
7. 各代替案に ◎/○/△/× の評価を付け、利点・欠点・根拠を記述する
8. CSD の Supposition/Doubt に依存する評価は明記する

### 出力フォーマット

`{evaluation_save_path}`（= `{work_dir}/eval-obj-{N}.md`）に output-schemas.md の eval-obj-{N}.md フォーマットで保存する。

### 返答フォーマット

```
{objective_id}: {目的名} — 評価完了
提案代替案: {N}件
評価済み代替案: {M}件
```

---

## Phase 4: 評価のみ（Level 1 の Objective Evaluator）

### 目的

ユーザーが提供した代替案を担当目的の観点から評価する。代替案生成はスキップ。

### 入力

- `{work_dir}/decision-statement.md`
- `{work_dir}/alternatives.md`（ユーザーが Phase 0 で提供）
- `{work_dir}/objectives.md`
- `{work_dir}/research.md`
- `{work_dir}/prior-decisions.md`（存在する場合）
- `{skill_dir}/references/agent-prompts.md` の Objective Evaluator セクション
- `{objective_id}`: 担当する目的の ID

### 処理手順

1. agent-prompts.md の Objective Evaluator セクションの行動指針を確認する
2. alternatives.md の全代替案を担当目的の観点から評価する
3. 各代替案に ◎/○/△/× の評価を付け、利点・欠点・根拠を記述する

### 出力フォーマット

`{evaluation_save_path}` に output-schemas.md の eval-obj-{N}.md フォーマットで保存する。
「提案した代替案」セクションは「Level 1: 省略」と記載する。

### 返答フォーマット

```
{objective_id}: {目的名} — 評価完了（Level 1）
評価済み代替案: {M}件
```

---

## Phase 5: プレモーテム分析

### 目的

有力な選択肢に対して「失敗した未来」を想定し、見落とされたリスクを発見する。

### 入力

- `{work_dir}/alternatives.md`
- `{work_dir}/evaluation-matrix.md`
- `{work_dir}/csd-final.md`
- `{skill_dir}/references/agent-prompts.md` の Premortem Analyst セクション

### 処理手順

1. agent-prompts.md の Premortem Analyst セクションの行動指針を確認する
2. evaluation-matrix.md から有力な選択肢を1-2件特定する（総合的に評価が高い選択肢）
3. 各有力選択肢に対して以下の前提で思考する:
   「この選択肢が採用された。1年後、この決定は深刻な問題を引き起こしている。何が起きたか？」
4. CSD の Supposition の崩壊シナリオを必ず含める
5. Phase 4 で指摘された欠点がどう具体的な失敗に発展するかを描写する
6. 技術的・組織的・市場環境的な要因を含める
7. 各シナリオに深刻度・発生確率・軽減策を付記する

### 出力フォーマット

`{work_dir}/premortem.md` に output-schemas.md の premortem.md フォーマットで保存する。
有力選択肢1-2件 × 各3-5件の失敗シナリオ。

### 返答フォーマット

```
プレモーテム分析完了: {N}件の選択肢を分析、計{M}件の失敗シナリオを生成
```

---

## Phase 6: 連鎖する意思決定の検証

### 目的

今回の決定が将来の意思決定の選択肢をどう制限/拡大するかを分析する。

### 入力

- `{work_dir}/decision-statement.md`
- `{work_dir}/alternatives.md`
- `{work_dir}/evaluation-matrix.md`
- `{skill_dir}/references/agent-prompts.md` の Future Analyst セクション

### 処理手順

1. agent-prompts.md の Future Analyst セクションの行動指針を確認する
2. 今後1-3年で発生しうる関連する意思決定ポイントを特定する
3. 各代替案がそれらの将来の決定にどう影響するかを評価する
   - 選択肢が広がる / 狭まる / 中立
4. 各代替案の可逆性を評価する（可逆/部分可逆/不可逆）

### 出力フォーマット

`{work_dir}/linked-decisions.md` に output-schemas.md の linked-decisions.md フォーマットで保存する。

### 返答フォーマット

```
連鎖分析完了: {N}件の将来の決定ポイントを特定
```

---

## Phase 7: 審議サマリー生成

### 目的

全フェーズの結果を人間が最終判断できる形式に統合する。

### 入力（レベルに応じて）

- 全レベル: `{work_dir}/decision-statement.md`, `{work_dir}/objectives.md`, `{work_dir}/alternatives.md`, `{work_dir}/evaluation-matrix.md`
- 全レベル（存在する場合）: `{work_dir}/prior-decisions.md`
- Level 2/3: `{work_dir}/csd-final.md`
- Level 3: `{work_dir}/premortem.md`, `{work_dir}/linked-decisions.md`
- `{level}`: 実行レベル

### 処理手順

1. 全入力ファイルを読み込む
2. 以下の構造で審議サマリーを生成する:
   - 決定ステートメント
   - 関連する既存決定 — prior-decisions.md が存在する場合。存在しない場合は省略
   - 前提条件（CSD）— Level 1 では「スキップ」
   - 判断基準
   - 検討した選択肢
   - トレードオフ行列
   - リスク分析 — Level 3 のみ
   - 将来の意思決定への影響 — Level 3 のみ
   - 判断ガイド
   - 不確実性の影響 — Level 2/3（CSD の Doubt 項目が存在する場合）
3. **不確実性の影響の記述ルール**（Level 2/3、CSD の Doubt 項目が存在する場合）:
   - csd-final.md の各 Doubt 項目について、「その不確実性が判明した場合に各選択肢の評価がどう変化するか」を記述する
   - 形式: 「{Doubt項目}が判明した場合 → {選択肢の評価への影響}」
   - Level 1 または Doubt 項目が存在しない場合は省略する
4. **判断ガイドの記述ルール**:
   - 条件付き提示のみ: 「{目的}を最優先するなら→{選択肢}が適している。ただし{別の目的}にリスクがある。」
   - 「〜を推奨します」「〜がベストです」は禁止
   - 目的間の優先度を設定しない
   - 不確実性を隠さない

### 出力フォーマット

`{work_dir}/deliberation-summary.md` に output-schemas.md の deliberation-summary.md フォーマットで保存する。

### 返答フォーマット

```
審議サマリー生成完了: 代替案{N}件, 判断基準{M}件
```

---

## Phase 8: ADR生成

### 目的

審議結果とユーザーの決定を統合してADR文書を生成する。

### 入力

- `{work_dir}/` 内の全中間ファイル（レベルに応じて存在するもの）
- `{skill_dir}/references/output-schemas.md` のADRテンプレート
- `{adr_path}`: ADRファイルの保存先パス
- `{adr_number}`: ADR番号（4桁ゼロ埋め）
- `{selected_alternative}`: ユーザーが選択した代替案
- `{user_rationale}`: ユーザーが提供した選択理由
- `{accepted_tradeoffs}`: ユーザーが明示した受け入れるトレードオフ
- `{level}`: 実行レベル

### 処理手順

1. output-schemas.md のADRテンプレートを読み込む
2. レベル別セクション省略ルールを確認する
3. 中間ファイルからADRの各セクションを構成する:
   - コンテキスト ← decision-statement.md
   - 関連する既存決定 ← prior-decisions.md（存在する場合）。存在しない場合はセクション省略
   - 前提条件 ← csd-final.md（Level 2/3）またはLevel 1省略注記
   - 判断基準 ← objectives.md
   - 検討した選択肢 ← alternatives.md + evaluation-matrix.md
   - トレードオフ分析 ← evaluation-matrix.md
   - リスク分析 ← premortem.md（Level 3）または省略注記
   - 将来の意思決定への影響 ← linked-decisions.md（Level 3）または省略注記
   - 決定 ← `{selected_alternative}`
   - 根拠 ← `{user_rationale}`
   - 受け入れたトレードオフ ← `{accepted_tradeoffs}`
4. ステータスは「Proposed」、日付は当日
5. `{adr_path}` に Write で保存する

### 出力フォーマット

output-schemas.md のADRテンプレートに厳密に従う。

### 返答フォーマット

```
ADR生成完了: {adr_path}
```
