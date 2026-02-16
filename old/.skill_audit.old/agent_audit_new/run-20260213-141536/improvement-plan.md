# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 0 グループ分類のサブエージェント化、agent_name導出ルール明確化、構造検証範囲拡大、知見蓄積機構追加、Phase 2 Step 4 のインライン化、Phase 2 Step 2a 処理ルール追加、グループ分類優先順序明記、Phase 1 findings 読み込み重複削減 | I-1, I-2, I-3, I-4, I-5, I-6, I-8, I-9 |
| 2 | group-classification.md | 修正 | 同数時の優先順序追加 | I-8 |
| 3 | agents/evaluator/criteria-effectiveness.md | 修正 | Phase 1/2 共通セクション外部化 | I-7 |
| 4 | agents/evaluator/scope-alignment.md | 修正 | Phase 1/2 共通セクション外部化 | I-7 |
| 5 | agents/evaluator/detection-coverage.md | 修正 | Phase 1/2 共通セクション外部化 | I-7 |
| 6 | agents/producer/workflow-completeness.md | 修正 | Phase 1/2 共通セクション外部化 | I-7 |
| 7 | agents/producer/output-format.md | 修正 | Phase 1/2 共通セクション外部化 | I-7 |
| 8 | agents/shared/instruction-clarity.md | 修正 | Phase 1/2 共通セクション外部化 | I-7 |
| 9 | agents/unclassified/scope-alignment.md | 修正 | Phase 1/2 共通セクション外部化 | I-7 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**:
- I-1 (efficiency): Phase 0 グループ分類のコンテキスト保持
- I-2 (stability): agent_name導出ルールで「プロジェクトルート」が未定義
- I-3 (architecture): 構造検証の範囲不足
- I-4 (architecture): 知見蓄積の不在
- I-5 (architecture): テンプレート外部化の過剰適用
- I-6 (stability): Phase 2 Step 2a の "Other" 選択後のループ継続条件が未定義
- I-8 (stability): グループ分類での「主たる機能」判定基準が曖昧
- I-9 (efficiency): Phase 1 findings ファイル読み込みの重複

**変更内容**:

#### 変更1: Phase 0 Step 4 グループ分類のサブエージェント化（I-1対応）
- **現在の記述（行64-79）**: `{agent_content}` を親コンテキストで保持し、メインコンテキストで直接判定
- **改善後の記述**: グループ分類をサブエージェント（Task ツール、haiku モデル）に委譲し、結果のみ受け取る。`{agent_content}` の保持を削除
```markdown
4. Task ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "haiku"`）:

   `.claude/skills/agent_audit_new/group-classification.md` を Read し、その指示に従ってグループ分類を実行してください。
   分析対象: `{agent_path}`
   分類完了後、以下のフォーマットで返答してください: `group: {agent_group}`

サブエージェント完了後、返答から `{agent_group}` を抽出する。
```

#### 変更2: Phase 0 Step 5 agent_name導出ルール明確化（I-2対応）
- **現在の記述（行86）**: 「プロジェクトルートからの相対パス」
- **改善後の記述**: 「current working directory からの相対パス」

#### 変更3: Phase 2 検証ステップの拡大（I-3対応）
- **現在の記述（行239-245）**: YAML frontmatter 存在確認のみ
- **改善後の記述**: グループに応じた必須セクション検証を追加
```markdown
2. 構造検証:
   - YAML frontmatter の存在確認（ファイル先頭が `---` で始まり、`description:` を含む）
   - グループ別必須セクション検証:
     - **evaluator/hybrid**: "## Findings" セクションの存在
     - **producer/hybrid**: "## Workflow" または "Phase" セクションの存在
     - **全グループ**: YAML frontmatter 内の `name:` と `description:` フィールドの存在
```

#### 変更4: Phase 0 への知見参照追加（I-4対応）
- **現在の記述（行61-66）**: Phase 0 は初期化のみで前回結果を参照しない
- **改善後の記述**: Phase 0 Step 6a を追加
```markdown
6a. 前回実行履歴の確認:
   - `.agent_audit/{agent_name}/audit-approved.md` が存在する場合、Read で読み込み、`{previous_approved_count}` を抽出する
   - 存在しない場合は、`{previous_approved_count} = 0` とする
   - `{previous_approved_count} > 0` の場合、テキスト出力: `前回実行で {previous_approved_count} 件の指摘が承認されています。解決済み指摘として次元エージェントに渡します。`
```

Phase 1 の Task prompt を以下に変更:
```markdown
> `.claude/skills/agent_audit_new/agents/{dim_path}.md` を Read し、その指示に従って分析を実行してください。
> 分析対象: `{agent_path}`, agent_name: `{agent_name}`
> 前回承認済み findings（既知の問題）: `{previous_approved_path}` （存在しない場合は空とみなす）
> findings の保存先: `{findings_save_path}`（= `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` の絶対パス）
> 分析完了後、以下のフォーマットで返答してください: `dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`
```

各次元エージェントは前回承認済み findings を Read し、同一の指摘を検出した場合、finding に `[resolved in previous run]` タグを付与する。

#### 変更5: Phase 2 Step 4 の改善適用ルールインライン化（I-5対応）
- **現在の記述（行228-235）**: `templates/apply-improvements.md` を Read してサブエージェントに渡す
- **改善後の記述**: 主要ルールを SKILL.md Phase 2 Step 4 にインライン化
```markdown
`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

以下の手順で承認済み監査 findings に基づいてエージェント定義を改善してください:

1. Read で以下のファイルを読み込む:
   - `{approved_findings_path}` （承認済み findings — 改善内容と推奨を含む）
   - `{agent_path}` （エージェント定義 — 変更対象）

2. **適用順序の決定**: 全 findings の変更対象箇所をマッピングし、以下の順序ルールに従って適用順序を決定する:
   - **削除** → **統合** → **修正** → **追加** （範囲の大きい変更から小さい変更へ）
   - 同一箇所に複数の findings が影響する場合: 矛盾がないか確認し、矛盾がある場合は後続の finding を skipped に記録する

3. 決定した順序で findings を適用する。各 finding について:
   - **二重適用チェック**: Edit 前に対象箇所の現在の内容が findings の前提と一致するか確認する。一致しない場合（既に改善済みまたは別の変更あり）はその変更をスキップし、skipped リストに理由を記録する
   - **ユーザー修正内容の優先**: finding に「修正内容」が記載されている場合、finding の「推奨」を無視し、ユーザーの修正内容のみに基づいて変更する。修正内容が不明確な場合は skipped に記録する
   - Edit を優先する（部分的な変更は必ず Edit）
   - Write はファイル全体の書き換えが必要な場合のみ使用する
   - 変更前にファイルの Read を必ず実行する（Read なしの Edit/Write は禁止）
   - 承認済み findings に記載されていない変更は行わない

パス変数:
- `{agent_path}`: {実際の agent_path の絶対パス}
- `{approved_findings_path}`: {実際の .agent_audit/{agent_name}/audit-approved.md の絶対パス}

以下のフォーマットで**結果のみ**返答してください:
```
modified: {N}件
  - {finding ID} → {ファイルパス}:{セクション名}: {変更概要}
skipped: {K}件
  - {finding ID}: {スキップ理由}
```

**上限**: modified リストは最大20件まで（超過分は `... and {N} more` で省略）、skipped リストは最大10件まで（超過分は `... and {N} more` で省略）
```

#### 変更6: Phase 2 Step 2a の "Other" 選択処理追加（I-6対応）
- **現在の記述（行188-192）**: "Other" 選択時の処理が簡潔
- **改善後の記述**:
```markdown
ユーザーが "Other" で修正内容をテキスト入力した場合は「修正して承認」として扱い、改善計画に含める。入力内容が不明確な場合（2行以下で具体性なし、文脈不明）、再度 AskUserQuestion で「入力内容が不明確です。詳細を追加するか、Approve/Skip のいずれかを選択してください。」と確認する（最大1回のみ再確認。2回目の入力が不明確な場合はスキップとして扱う）。
```

#### 変更7: Phase 0 グループ分類への優先順序追記（I-8対応）
- **現在の記述（行72-77）**: 判定ルール（概要）に同数時の処理なし
- **改善後の記述**:
```markdown
判定ルール（概要）:
1. evaluator 特徴が3つ以上 **かつ** producer 特徴が3つ以上 → **hybrid**
2. evaluator 特徴が3つ以上 → **evaluator**
3. producer 特徴が3つ以上 → **producer**
4. 上記いずれにも該当しない → **unclassified**

特徴数が同数の場合（evaluator=3, producer=3）、hybrid と判定される（ルール1）。evaluator と producer が両方3未満で同数の場合は unclassified（ルール4）。
```

#### 変更8: Phase 1 findings ファイル読み込み重複削減（I-9対応）
- **現在の記述（行132-143）**: Phase 1 完了後に findings ファイルを Read して Summary 抽出、Phase 2 Step 1 で再度 Read
- **改善後の記述**: Phase 1 の Summary 抽出結果を変数 `{dim_summaries}` として保持し、Phase 2 Step 1 での Read を省略

Phase 1 エラーハンドリング（行132-143）:
```markdown
**エラーハンドリング**: 各サブエージェントの成否を以下で判定する:
- 対応する findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）が存在し、空でない → 成功。件数はサブエージェント返答から抽出し、`{dim_summaries}` に保存する（`{次元名}: critical {N}, improvement {M}, info {K}`）。抽出失敗時は findings ファイルを Read し、`## Summary` セクション内の件数を抽出する
- findings ファイルが存在しない、または空 → 失敗。該当次元は「分析失敗（{エラー概要}）」として `{dim_summaries}` に記録する
```

Phase 2 Step 1（行154-157）:
```markdown
#### Step 1: Findings の収集

Phase 1 で成功した全次元の findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）を Read する。各ファイルから severity が critical または improvement の finding（`###` ブロック単位）を抽出し、critical → improvement の順にソートする。
`{total}` = 対象 finding の合計件数。critical と improvement の件数は `{dim_summaries}` から集計する。
```

---

### 2. group-classification.md（修正）
**対応フィードバック**: I-8 (stability): グループ分類での「主たる機能」判定基準が曖昧

**変更内容**:

#### 変更1: 判定ルールへの優先順序追加（I-8対応）
- **現在の記述（行17-21）**: 判定ルールに同数時の処理なし
- **改善後の記述**:
```markdown
## 判定ルール
1. evaluator 特徴が3つ以上 **かつ** producer 特徴が3つ以上 → **hybrid**
2. evaluator 特徴が3つ以上 → **evaluator**
3. producer 特徴が3つ以上 → **producer**
4. 上記いずれにも該当しない → **unclassified**

**同数時の処理**: evaluator=3, producer=3 の場合、ルール1により hybrid と判定される。evaluator と producer が両方3未満で同数（例: evaluator=2, producer=2）の場合は unclassified（ルール4）。
```

---

### 3-9. agents/（全次元エージェント）（修正）
**対応フィードバック**: I-7 (efficiency): 次元エージェントファイルの冗長性

**変更内容**:

#### 変更1: Phase 1/2 共通セクションの外部化（I-7対応）
- **現在の記述**: 6つの次元エージェントファイル（criteria-effectiveness.md, scope-alignment.md（evaluator版）, detection-coverage.md, workflow-completeness.md, output-format.md, instruction-clarity.md, scope-alignment.md（unclassified版））に共通の以下セクションが重複:
  - "Analysis Process - Detection-First, Reporting-Second" の説明（2段階プロセス）
  - Phase 1/2 の構造説明
  - 5つの Detection Strategy の概念説明

- **改善後の記述**: 共通テンプレート `agents/shared/analysis-framework.md` を新規作成し、各次元エージェントファイルは次元固有の検出ロジックのみ定義

各次元エージェントファイルの冒頭（frontmatter 直後）に以下を追加:
```markdown
**共通フレームワーク**: 分析プロセスの基本構造（2段階プロセス、Detection Strategies の概念）は `.claude/skills/agent_audit_new/agents/shared/analysis-framework.md` を参照してください。以下は {次元名} 固有の検出ロジックです。
```

各次元エージェントファイルから以下セクションを削除:
- "Analysis Process - Detection-First, Reporting-Second" の説明段落（共通部分のみ削除、次元固有の注釈は保持）
- Phase 1/2 の構造説明（"## Phase 1: Comprehensive Problem Detection" と "## Phase 2: Organization & Reporting" の冒頭説明段落。各 Phase の Detection Strategy や Severity Rules は次元固有のため保持）

---

## 新規作成ファイル

| ファイル | 目的 | 対応フィードバック |
|---------|------|------------------|
| agents/shared/analysis-framework.md | 全次元エージェント共通の2段階プロセス説明とDetection Strategiesの概念を定義 | I-7 |

### agents/shared/analysis-framework.md の内容案

```markdown
# 分析フレームワーク（全次元共通）

このドキュメントは、agent_audit スキルの全分析次元で使用する共通の分析プロセスとDetection Strategiesの概念を定義します。各次元エージェントは、このフレームワークに基づき、次元固有の検出ロジックを実装します。

## 2段階分析プロセス

### Phase 1: Comprehensive Problem Detection（包括的問題検出）

**目的**: 出力形式や組織化を気にせず、全ての問題を網羅的に検出する。**敵対的思考を用いて微妙な違反を発見する。**

エージェント定義全体を読み込み、複数の Detection Strategy を用いて体系的に問題を検出します。

**Phase 1 の出力形式**: 構造化されていない、包括的な問題リストを作成する。箇条書きを使用する。まだ severity による整理は行わない。組織化よりも網羅性を重視する。

### Phase 2: Organization & Reporting（整理と報告）

**目的**: Phase 1 で検出した包括的な問題リストを、明確で優先順位付けされた報告書に整理する。

#### Severity 分類

Phase 1 の各問題を severity で分類します:
- **critical**: エージェントのパフォーマンスを直接害する、または実行不可能な問題
- **improvement**: 効率・明確性・保守性に影響する改善機会
- **info**: 有効だが、マイナーな最適化機会がある

#### 報告書の構成

findings を severity 順（critical → improvement → info）に整理し、各 finding に以下の情報を含めます:
- 内容: 問題の説明
- 根拠: 問題の証拠（関連する記述の引用）
- 推奨: 改善案（具体的な修正例を含む）

## Detection Strategies の概念

各次元は複数の Detection Strategy を用いて問題を検出します。Detection Strategy とは、特定の観点から体系的に問題を発見するためのアプローチです。

典型的な Detection Strategy の種類:
1. **Inventory & Classification**: 対象要素を列挙し、分類する
2. **Adversarial Testing**: 敵対的な質問を用いて脆弱性を発見する
3. **Feasibility Analysis**: 実行可能性を評価する
4. **Consistency Analysis**: 要素間の整合性を検証する
5. **Antipattern Matching**: 既知の問題パターンと照合する

各次元エージェントは、次元固有の Detection Strategy を定義します（例: Criteria Effectiveness 次元では "Criteria Inventory & Classification", "Adversarial Robustness Testing" 等）。

## 敵対的思考（Adversarial Mindset）

分析時には、以下の敵対的視点を採用します:
- **実装者視点**: 低品質な出力を生成しながら、技術的には基準を満たす方法を探す
- **回避テスト**: 「この基準を技術的に満たしながら、実際には不十分な出力を生成できるか？」
- **曖昧性の悪用**: 「不明確な指示を、最も楽な解釈で満たせるか？」

この視点により、表面的には厳密に見えるが、実際には機能しない基準・指示を発見できます。
```

---

## 削除推奨ファイル

| ファイル | 理由 | 対応フィードバック |
|---------|------|------------------|
| templates/apply-improvements.md | SKILL.md Phase 2 Step 4 にインライン化されるため不要 | I-5 |

---

## 実装順序

1. **agents/shared/analysis-framework.md を新規作成**（I-7対応）
   - 理由: 次元エージェントファイル（3-9）が参照するため、先に作成が必要

2. **group-classification.md を修正**（I-8対応）
   - 理由: SKILL.md Phase 0 Step 4 のサブエージェント化で参照される。サブエージェント prompt がこのファイルを Read するため、先に更新が必要

3. **SKILL.md を修正**（I-1, I-2, I-3, I-4, I-5, I-6, I-8, I-9対応）
   - 理由: ワークフローのメイン定義。変更1（サブエージェント化）が group-classification.md を参照、変更4（知見蓄積）が次元エージェント prompt を変更、変更5（インライン化）が templates/apply-improvements.md の削除前提

4. **agents/ 配下の7つの次元エージェントファイルを並列修正**（I-7対応）
   - 理由: 互いに依存関係がなく、全て analysis-framework.md を参照するのみ
   - 対象: agents/evaluator/criteria-effectiveness.md, agents/evaluator/scope-alignment.md, agents/evaluator/detection-coverage.md, agents/producer/workflow-completeness.md, agents/producer/output-format.md, agents/shared/instruction-clarity.md, agents/unclassified/scope-alignment.md

5. **templates/apply-improvements.md を削除**（I-5対応）
   - 理由: SKILL.md の変更完了後、参照がなくなるため削除可能

依存関係の検出方法:
- 改善Aの成果物（新規ファイル、変更後の内容）を改善Bが参照する場合、Aを先に実施
- 例: テンプレート新規作成（A）→ SKILL.md でのテンプレート参照追加（B）→ Aが先

---

## 注意事項

- 変更によって既存のワークフローが壊れないこと
  - 特に Phase 0 Step 4 のサブエージェント化（変更1）は、`{agent_content}` 変数を削除するため、他の箇所で参照していないか確認が必要
  - Phase 1 の findings 読み込み削減（変更8）は、Phase 2 Step 1 のロジックと整合していることを確認
- テンプレート外部化の場合、SKILL.md の参照箇所も同時に更新すること
  - 変更5（apply-improvements.md のインライン化）は、Phase 2 Step 4 の Task prompt 全体を書き換える
- 新規テンプレートのパス変数が SKILL.md で定義されていること
  - 変更4（知見蓄積）で追加する `{previous_approved_path}` 変数は Phase 0 Step 6a で定義される
- agents/ 配下の変更（I-7）は、既存の Detection Strategy や Severity Rules を削除しないこと
  - 共通フレームワークへの参照追加と、重複する**概念説明のみ**削除
