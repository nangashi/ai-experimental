# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 0: group-classification.md の内容をインライン化 | I-8 |
| 2 | SKILL.md | 修正 | Phase 1: サブエージェント返答フォーマットの明示化と複雑な抽出ロジックの削除 | C-3 |
| 3 | SKILL.md | 修正 | Phase 2 Step 2: 「全て承認」オプション削除または再確認ステップ追加 | I-1 |
| 4 | SKILL.md | 修正 | Phase 2 Step 2a: 「Other」入力記述の削除と選択肢の明示化 | C-1 |
| 5 | SKILL.md | 修正 | Phase 2 Step 2a: 「残りすべて承認」選択時の再確認ステップ追加 | I-5 |
| 6 | SKILL.md | 修正 | Phase 2 Step 4: サブエージェント prompt のパス変数展開削除 | C-2 |
| 7 | SKILL.md | 修正 | Phase 2 Step 4 検証: frontmatter 比較ベースの検証に変更 | I-2 |
| 8 | SKILL.md | 修正 | Phase 2 Step 4 検証: 変更行数チェック追加 | I-4 |
| 9 | SKILL.md | 修正 | Phase 3: 失敗次元の扱いをサマリに追加 | I-3 |
| 10 | SKILL.md | 修正 | Phase 1-2 統合: findings ファイルの重複 Read 削除 | I-6 |
| 11 | templates/apply-improvements.md | 修正 | agent_path の二重 Read 防止の明示化 | I-7 |
| 12 | agents/shared/instruction-clarity.md | 修正 | 2フェーズ構造を単一パス構造に簡略化 | I-9 |
| 13 | agents/evaluator/criteria-effectiveness.md | 修正 | 2フェーズ構造を単一パス構造に簡略化 | I-9 |
| 14 | agents/evaluator/scope-alignment.md | 修正 | 2フェーズ構造を単一パス構造に簡略化 | I-9 |
| 15 | agents/evaluator/detection-coverage.md | 修正 | 2フェーズ構造を単一パス構造に簡略化 | I-9 |
| 16 | agents/producer/workflow-completeness.md | 修正 | 2フェーズ構造を単一パス構造に簡略化 | I-9 |
| 17 | agents/producer/output-format.md | 修正 | 2フェーズ構造を単一パス構造に簡略化 | I-9 |
| 18 | agents/unclassified/scope-alignment.md | 修正 | 2フェーズ構造を単一パス構造に簡略化 | I-9 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）- Phase 0: group-classification.md インライン化
**対応フィードバック**: I-8

**変更内容**:
- L71-83 (グループ分類セクション): group-classification.md の全内容（evaluator特徴4項目、producer特徴4項目、判定ルール4項目）を SKILL.md L73-83 の間に直接展開する
- L74: `.claude/skills/agent_audit_new/group-classification.md を参照` → 削除し、特徴リストと判定ルールを直接記載
- L77-81: 現在の「判定ルール（概要）」→「判定ルール」に変更し、group-classification.md の完全な判定ルールをインライン化

**具体的な記述例**:
```markdown
#### グループ分類

4. `{agent_content}` を分析し、`{agent_group}` を以下の基準で判定する:

   **evaluator 特徴**（4項目）:
   - 評価基準・チェックリスト・検出ルールが定義されている
   - 入力に対して問題点・改善点・findings を出力する構造がある
   - 重要度・深刻度（severity, critical, significant 等）による分類がある
   - 評価スコープ（何を評価するか/しないか）が定義されている

   **producer 特徴**（4項目）:
   - ステップ・手順・ワークフローに従って成果物を作成する構造がある
   - 出力がファイル・コード・文書・計画などの成果物である
   - 入力を変換・加工・生成する処理が主体である
   - ツール操作（Read/Write/Edit/Bash 等）による作業手順が記述されている

   **判定ルール**:
   1. evaluator 特徴が3つ以上 **かつ** producer 特徴が3つ以上 → **hybrid**
   2. evaluator 特徴が3つ以上 → **evaluator**
   3. producer 特徴が3つ以上 → **producer**
   4. 上記いずれにも該当しない → **unclassified**

   この判定はメインコンテキストで直接行う（サブエージェント不要）。
```

---

### 2. SKILL.md（修正）- Phase 1: サブエージェント返答フォーマットの明示化
**対応フィードバック**: C-3

**変更内容**:
- L130: `分析完了後、エージェント定義内の「Return Format」セクションに従って返答してください。` → `分析完了後、以下のフォーマットで必ず返答してください: dim: {ID}\ncritical: {N}\nimprovement: {M}\ninfo: {K}`
- L138: findings ファイルからの件数抽出ロジック全体を削除し、サブエージェント返答の直接パースに置換
- 削除する内容: `件数はファイル内の ## Summary セクションから抽出する（抽出失敗時は Grep を使用して findings ファイル内の ^### {ID_PREFIX}- パターンを検索し、マッチ数から推定する。両方失敗した場合は critical: 0, improvement: 0, info: 0 を使用する）`
- 新規記述: `サブエージェントの返答から dim, critical, improvement, info を抽出する。返答フォーマットに従っていない場合は、該当次元を「分析失敗（不正な返答フォーマット）」として扱う`

---

### 3. SKILL.md（修正）- Phase 2 Step 2: 「全て承認」オプション削除
**対応フィードバック**: I-1

**変更内容**:
- L175-178: 承認方針選択の選択肢を変更
- 削除: `**「全て承認」**: 全 findings を承認として Step 3 へ進む`
- 選択肢を2つに削減: 「1件ずつ確認」/ 「キャンセル」のみ

**記述例**:
```markdown
続けて `AskUserQuestion` で承認方針を確認:
- **「1件ずつ確認」**: Step 2a の per-item 承認ループに入る
- **「キャンセル」**: 改善適用なしで Phase 3 へ直行する
```

---

### 4. SKILL.md（修正）- Phase 2 Step 2a: 「Other」入力記述の削除
**対応フィードバック**: C-1

**変更内容**:
- L193: `続けて AskUserQuestion で方針確認（選択肢は以下の4つ。ユーザーが "Other" で修正内容をテキスト入力した場合は「修正して承認」として扱い、改善計画に含める）:` → `続けて AskUserQuestion で方針確認（選択肢は以下の4つ）:`
- 「Other」に関する記述を完全削除
- 選択肢を明示的に列挙（承認/スキップ/残りすべて承認/キャンセル）

---

### 5. SKILL.md（修正）- Phase 2 Step 2a: 「残りすべて承認」再確認ステップ
**対応フィードバック**: I-5

**変更内容**:
- L196: `**「残りすべて承認」**: この指摘を含め、未確認の全指摘を承認としてループを終了する` の直後に再確認ステップを追加
- 追加記述: `（選択時、残りの findings の一覧を表示し、AskUserQuestion で「本当に残り全て承認しますか？」を確認する。「はい」で承認、「いいえ」で次の指摘へ戻る）`

---

### 6. SKILL.md（修正）- Phase 2 Step 4: パス変数展開削除
**対応フィードバック**: C-2

**変更内容**:
- L235-236: 変数を波括弧付きプレースホルダのまま渡す
- 変更前: `- {agent_path}: {実際の agent_path の絶対パス}` / `- {approved_findings_path}: {実際の .agent_audit/{agent_name}/audit-approved.md の絶対パス}`
- 変更後: `- {agent_path}: エージェント定義ファイルの絶対パス（{実際のパス}）` / `- {approved_findings_path}: 承認済み findings ファイルの絶対パス（{実際のパス}）`

**記述例**:
```markdown
`.claude/skills/agent_audit_new/templates/apply-improvements.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数（波括弧付きプレースホルダとして渡す）:
- {agent_path}: {agent_path の実際の絶対パス値}
- {approved_findings_path}: {approved_findings_path の実際の絶対パス値}
```

---

### 7. SKILL.md（修正）- Phase 2 Step 4 検証: frontmatter 比較ベース
**対応フィードバック**: I-2

**変更内容**:
- L249-254: 検証ステップの基準を変更
- 変更前: `2. YAML frontmatter の存在確認（ファイル先頭が --- で始まり、description: を含む）`
- 変更後: `2. バックアップファイル（{backup_path}）と改善適用後ファイル（{agent_path}）の frontmatter セクションを比較し、frontmatter が破損していないか確認する`
- L253: `✓ 検証完了: エージェント定義の構造は正常です` → `✓ 検証完了: frontmatter は改善適用前後で一致しています`
- L254: `✗ 検証失敗: エージェント定義が破損している可能性があります` → `✗ 検証失敗: frontmatter が改善適用前後で異なります。破損の可能性があります`

---

### 8. SKILL.md（修正）- Phase 2 Step 4 検証: 変更行数チェック追加
**対応フィードバック**: I-4

**変更内容**:
- L249-254: 検証ステップに以下を追加（frontmatter 比較の後）
- 追加記述:
  ```markdown
  3. 変更行数チェック: Bash で `diff {backup_path} {agent_path} | grep -E '^[<>]' | wc -l` を実行し、変更行数を取得
  4. バックアップファイルの行数と比較し、変更行数が元行数の50%を超える場合は警告を表示: `⚠ 警告: 変更行数が元ファイルの50%を超えています（{変更行数}/{元行数}行）。大規模削除・追加が発生した可能性があります`
  ```

---

### 9. SKILL.md（修正）- Phase 3: 失敗次元の扱い追加
**対応フィードバック**: I-3

**変更内容**:
- L280: `- 分析次元: {dim_count}件（{各次元名}）` → `- 分析次元: {成功次元数}/{全次元数}件（成功: {成功次元名のカンマ区切り}）`
- Phase 1 で失敗次元がある場合、L281 の直後に追加: `- 失敗次元: {失敗次元のID列挙}（{エラー概要}）`

---

### 10. SKILL.md（修正）- Phase 1-2 統合: findings 重複 Read 削除
**対応フィードバック**: I-6

**変更内容**:
- L138: Phase 1 完了時の件数抽出を削除し、findings ファイルの Read を省略
- L143-148: テキスト出力の件数情報をサブエージェント返答のみから取得
- L160: `Phase 1 で成功した全次元の findings ファイル（.agent_audit/{agent_name}/audit-{ID_PREFIX}.md）を Read する` → `Phase 1 で成功した全次元の findings ファイル（.agent_audit/{agent_name}/audit-{ID_PREFIX}.md）を1回だけ Read し、findings 内容を変数に保持する。以降は保持した内容を使用する`
- Phase 1 の返答サマリに件数のみを記録し、詳細は Phase 2 で一度だけ Read する構造に変更

---

### 11. templates/apply-improvements.md（修正）- 二重 Read 防止
**対応フィードバック**: I-7

**変更内容**:
- L3-5: Read 指示を維持
- L24: `変更前にファイルの Read を必ず実行する` → `変更前に、L3-5 で Read した内容を保持している場合はそれを使用する。保持していない場合のみ Read を実行する`

**記述例**:
```markdown
1. Read で以下のファイルを読み込み、変数に保持する:
   - {approved_findings_path} （承認済み findings — 改善内容と推奨を含む）
   - {agent_path} （エージェント定義 — 変更対象）

（中略）

## 変更適用ルール
- **二重適用チェック**: Edit 前に対象箇所の現在の内容が findings の前提と一致するか確認する。L3-5 で Read した {agent_path} の内容を保持し、適用時の二重適用チェックではその保持内容を使用する。再度 Read する必要はない
```

---

### 12-18. agents 配下の全エージェント定義（修正）- 2フェーズ構造の簡略化
**対応フィードバック**: I-9

**対象ファイル**:
- agents/shared/instruction-clarity.md
- agents/evaluator/criteria-effectiveness.md
- agents/evaluator/scope-alignment.md
- agents/evaluator/detection-coverage.md
- agents/producer/workflow-completeness.md
- agents/producer/output-format.md
- agents/unclassified/scope-alignment.md

**変更内容**:
- 「## Phase 1: Comprehensive Problem Detection」および「## Phase 2: Organization & Reporting」セクションを削除
- 「**Analysis Process - Detection-First, Reporting-Second**」の記述を削除
- 新規構造: 「## Detection Strategy」→「## Output Format」の単一パス構造に置換

**新規構造例（instruction-clarity.md の場合）**:
```markdown
### Steps
1. Read `{agent_path}` to load the target agent definition.
2. Apply all detection strategies below to identify problems.
3. Organize findings by severity and generate output according to the Output Format section.

## Detection Strategies

Apply the following detection strategies systematically:

### Strategy 1: Document Structure Inventory
（既存の Detection Strategy 1 の内容をそのまま保持）

### Strategy 2: Role Definition Robustness Testing
（既存の Detection Strategy 2 の内容をそのまま保持）

（以下、全5 Detection Strategies を同様に保持）

### Severity Rules
（Phase 2 から移動）
- **critical**: ...
- **improvement**: ...
- **info**: ...

## Output Format
（Phase 2 の Output Format セクションをそのまま保持）
```

**期待効果**: 各エージェント定義を平均177行から約120行に圧縮（2フェーズ構造の説明・Phase 1/Phase 2 見出し・重複記述の削除により約60行削減）

---

## 新規作成ファイル

なし

---

## 削除推奨ファイル

| ファイル | 理由 | 対応フィードバック |
|---------|------|------------------|
| group-classification.md | SKILL.md の Phase 0 にインライン化されるため不要 | I-8 |

---

## 実装順序

1. **group-classification.md の削除** → SKILL.md Phase 0 へのインライン化（変更1）
   - 理由: 以降の変更で group-classification.md への参照がなくなるため、最初に統合する
2. **SKILL.md Phase 1 の返答フォーマット明示化**（変更2）
   - 理由: Phase 1-2 統合（変更10）の前提となる
3. **SKILL.md Phase 1-2 の findings 重複 Read 削除**（変更10）
   - 理由: Phase 1 の返答フォーマット変更（変更2）に依存
4. **SKILL.md Phase 2 の承認フロー修正**（変更3, 4, 5）
   - 理由: 独立した変更であり、並行可能
5. **SKILL.md Phase 2 Step 4 のパス変数展開削除**（変更6）
   - 理由: apply-improvements.md の変更（変更11）と同時に実施可能
6. **templates/apply-improvements.md の二重 Read 防止**（変更11）
   - 理由: SKILL.md の変更6と連動
7. **SKILL.md Phase 2 検証ステップの変更**（変更7, 8）
   - 理由: 独立した変更であり、並行可能
8. **SKILL.md Phase 3 のサマリ変更**（変更9）
   - 理由: 独立した変更
9. **agents 配下の全エージェント定義の簡略化**（変更12-18）
   - 理由: 全ファイルが同一パターンの変更であり、並行可能

---

## 注意事項

- **変更1（group-classification.md のインライン化）**: SKILL.md L74 の外部参照を削除し、L73-83 の間に group-classification.md の全内容を展開する。group-classification.md は削除推奨ファイルとして記録する
- **変更2（Phase 1 返答フォーマット）**: サブエージェントの返答フォーマットを必須とすることで、findings ファイルからの件数推定ロジックを削除できる。全エージェント定義（agents 配下）の Return Format セクションは既に正しいため、エージェント側の変更は不要
- **変更3（「全て承認」削除）**: 選択肢を「1件ずつ確認」と「キャンセル」の2つに削減することで、一括承認リスクを排除する
- **変更6（パス変数展開）**: サブエージェント prompt 内で `{agent_path}: {実際のパス}` の形式にすることで、テンプレート側が波括弧付きプレースホルダを認識できる
- **変更10（重複 Read 削除）**: Phase 1 完了時に findings ファイルを Read せず、サブエージェント返答のみから件数を取得する。Phase 2 で全 findings を1回だけ Read し、以降は保持した内容を使用する
- **変更12-18（エージェント簡略化）**: 全エージェント定義が同一の2フェーズ構造を持つため、パターン適用で一括変更可能。Detection Strategies の内容は保持し、Phase 1/Phase 2 の見出しと説明のみを削除する
