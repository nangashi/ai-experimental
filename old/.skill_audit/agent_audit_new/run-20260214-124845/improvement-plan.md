# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 0 の {agent_content} 保持削除、パス変数セクション追加、テンプレートパス修正、警告再表示追加、検証失敗時処理明確化、パス参照修正 | C-1, I-2, I-3, I-4, I-8, I-9 |
| 2 | templates/apply-improvements.md | 修正 | ディレクトリ構造説明を SKILL.md に移動 | I-1 |
| 3 | agents/shared/common-rules.md | 新規作成 | Severity Rules, Impact/Effort 定義等の共通説明セクション抽出 | I-6 |
| 4 | agents/shared/instruction-clarity.md | 修正 | 共通説明セクションの参照に置き換え | I-6 |
| 5 | agents/evaluator/criteria-effectiveness.md | 修正 | 共通説明セクションの参照に置き換え | I-6 |
| 6 | agents/evaluator/scope-alignment.md | 修正 | 共通説明セクションの参照に置き換え | I-6 |
| 7 | agents/evaluator/detection-coverage.md | 修正 | 共通説明セクションの参照に置き換え | I-6 |
| 8 | agents/producer/workflow-completeness.md | 修正 | 共通説明セクションの参照に置き換え | I-6 |
| 9 | agents/producer/output-format.md | 修正 | 共通説明セクションの参照に置き換え | I-6 |
| 10 | agents/unclassified/scope-alignment.md | 修正 | 共通説明セクションの参照に置き換え | I-6 |

## 変更ステップ

### Step 1: I-4 パス変数セクション追加
**対象ファイル**: SKILL.md
**変更内容**:
- 行11（## 使い方セクションの後）: パス変数セクションを追加
```markdown
## パス変数

- `{agent_path}`: エージェント定義ファイルの絶対パス（入力）
- `{agent_name}`: エージェント識別子（`.claude/` 配下の場合は `.claude/` からの相対パス、それ以外はプロジェクトルートからの相対パス、いずれも拡張子除去）
- `{agent_group}`: グループ分類結果（hybrid / evaluator / producer / unclassified）
- `{agent_content}`: エージェント定義ファイルの内容（Phase 0 Step 2 で読み込み、Phase 1 で削除予定）
- `{findings_save_path}`: 各次元の findings 保存先パス（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` の絶対パス）
- `{approved_findings_path}`: 承認済み findings の保存先パス（`.agent_audit/{agent_name}/audit-approved.md` の絶対パス）
- `{backup_path}`: 改善適用前のバックアップファイルパス（`{agent_path}.backup-YYYYMMDD-HHMMSS`）
- `{dim_count}`: 分析次元数
- `{dimensions}`: 分析次元セットのリスト
```

### Step 2: C-1 Phase 0 の {agent_content} 保持削除
**対象ファイル**: SKILL.md
**変更内容**:
- 行57（Phase 0 Step 2）: `{agent_content} として保持する` を削除し、`を読み込んで内容を確認する` に修正
```markdown
2. Read で `agent_path` のファイルを読み込んで内容を確認する。読み込み失敗時はエラー出力して終了
```
- 行58（Phase 0 Step 3）: `{agent_content}` の参照をファイル読み込みに置き換え
```markdown
3. ファイル内容の簡易チェック: `{agent_path}` を Read で読み込み、ファイル先頭に YAML frontmatter（`---` で囲まれたブロック内に `description:` を含む）が存在するか確認する。存在しない場合、警告フラグ `{frontmatter_warning}` を `true` に設定し、「⚠ このファイルにはエージェント定義の frontmatter がありません。エージェント定義ではない可能性があります。」とテキスト出力する（処理は継続する）
```
- 行62（グループ分類 Step 4）: `{agent_content}` の参照をファイル読み込みに置き換え
```markdown
4. `{agent_path}` を Read で読み込み、内容を分析して `{agent_group}` を以下の基準で判定する:
```
- 行115（Phase 1 Task prompt）: `{agent_content}` への言及を削除し、`{agent_path}` のみをサブエージェントに渡す
```markdown
> `.claude/skills/agent_audit_new/agents/{dim_path}.md` を Read し、その指示に従って分析を実行してください。
> 分析対象: `{agent_path}` （絶対パス）, agent_name: `{agent_name}`
> findings の保存先: `{findings_save_path}`（= `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` の絶対パス）
> 分析完了後、以下のフォーマットで返答してください: `dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`
```

### Step 3: I-2 Phase 0 frontmatter 警告の Phase 3 再表示
**対象ファイル**: SKILL.md
**変更内容**:
- 行244（Phase 3 Phase 2 がスキップされた場合の出力ブロック）: frontmatter 警告の再表示を追加
```markdown
Phase 2 がスキップされた場合（critical + improvement = 0）:
```
の後に以下を挿入:
```markdown
{frontmatter_warning} が true の場合:
```
⚠ 注意: このファイルにはエージェント定義の frontmatter がありませんでした。エージェント定義ではない可能性があります。
```

```
## agent_audit 完了
...
```
- 行254（Phase 2 が実行された場合の出力ブロック）: 同様に frontmatter 警告の再表示を追加

### Step 4: I-3 Phase 2 検証失敗時の処理継続明確化
**対象ファイル**: SKILL.md
**変更内容**:
- 行235（検証失敗時のテキスト出力）: 検証失敗時は Phase 3 のサマリ表示をスキップすることを明示
```markdown
4. 検証失敗時: 「✗ 検証失敗: エージェント定義が破損している可能性があります。以下のコマンドでロールバックできます: `cp {backup_path} {agent_path}`」とテキスト出力し、**Phase 3 の改善適用結果詳細表示をスキップして Phase 3 へ進む（警告のみ表示）**
```
- 行263（Phase 3 変更詳細セクション）: 検証失敗時の条件分岐を追加
```markdown
検証成功時のみ以下を表示:
- 変更詳細:
  - 適用成功: {N}件（{finding ID リスト}）
  - 適用スキップ: {K}件（{finding ID: スキップ理由}）
- バックアップ: {backup_path}（変更を取り消す場合: `cp {backup_path} {agent_path}`）

検証失敗時:
- ⚠ 検証失敗: エージェント定義が破損している可能性があります
- ロールバック: `cp {backup_path} {agent_path}`
```

### Step 5: I-5 findings ファイル再実行時の方針明記
**対象ファイル**: SKILL.md
**変更内容**:
- 行81（Phase 0 Step 6）: findings ファイルの上書き方針を明記
```markdown
6. 出力ディレクトリを作成する: `mkdir -p .agent_audit/{agent_name}/`
   - Phase 1 の各サブエージェントは既存の findings ファイルを Write で上書きする（再実行時は前回の findings は削除される）
```

### Step 6: I-8 SKILL.md 内のテンプレートパス修正
**対象ファイル**: SKILL.md
**変更内容**:
- 行221（Phase 2 Step 4 Task prompt）: テンプレートパスを修正
```markdown
`.claude/skills/agent_audit_new/templates/apply-improvements.md` を Read で読み込み、その内容に従って処理を実行してください。
```

### Step 7: I-9 SKILL.md 内の外部パス参照修正
**対象ファイル**: SKILL.md
**変更内容**:
- 行64（グループ分類基準の参照）: パスを修正
```markdown
   エージェント定義の **主たる機能** に注目して分類する。分類基準の詳細は `.claude/skills/agent_audit_new/group-classification.md` を参照。
```

### Step 8: I-1 ディレクトリ構造の説明追加
**対象ファイル**: SKILL.md
**変更内容**:
- 行10（## 使い方セクションの後）: ディレクトリ構造説明を追加
```markdown
## ディレクトリ構造

- `SKILL.md`: スキル定義メイン（ワークフロー、グループ分類、次元マッピング）
- `group-classification.md`: グループ分類基準詳細
- `agents/`: 分析次元エージェント定義
  - `shared/`: 全グループ共通の次元エージェント
    - `instruction-clarity.md`: IC 次元（指示明確性分析）
    - `common-rules.md`: 全次元エージェント共通のルール定義（Severity Rules, Impact/Effort 定義等）
  - `evaluator/`: evaluator / hybrid グループ向け次元エージェント
    - `criteria-effectiveness.md`: CE 次元（基準有効性分析）
    - `scope-alignment.md`: SA 次元（スコープ整合性分析）
    - `detection-coverage.md`: DC 次元（検出カバレッジ分析、evaluator のみ）
  - `producer/`: producer / hybrid グループ向け次元エージェント
    - `workflow-completeness.md`: WC 次元（ワークフロー完全性分析）
    - `output-format.md`: OF 次元（出力形式実現性分析）
  - `unclassified/`: unclassified グループ向け次元エージェント（軽量版）
    - `scope-alignment.md`: SA 次元（スコープ整合性分析・軽量版）
- `templates/`: サブエージェント用テンプレート
  - `apply-improvements.md`: Phase 2 Step 4 改善適用テンプレート
```

### Step 9: I-6 共通説明セクションの外部化準備（新規ファイル作成）
**対象ファイル**: agents/shared/common-rules.md（新規作成）
**変更内容**:
- 新規ファイル作成: 全次元エージェント共通の Severity Rules, Impact/Effort 定義を集約
```markdown
# 共通ルール定義

全次元エージェントが使用する共通のルール定義。

## Severity Rules

- **critical**: エージェントの実行が不可能、または実行結果が信頼できないレベルの致命的な問題（矛盾する指示、必須コンテキストの欠落、逆効果の基準、実行不可能な要求等）
- **improvement**: エージェントは実行できるが、品質・効率・信頼性に改善の余地がある問題（曖昧な基準、S/N比の低い基準、コンテキスト浪費、情報構造の最適化余地等）
- **info**: エージェントの動作に影響しないマイナーな最適化機会（軽微な冗長性、構造の微調整等）

## Impact Definition

- **High**: 実行不可能、信頼性に直接影響、またはコンテキスト浪費が 100 行以上
- **Medium**: 実行可能だが品質・効率に影響、コンテキスト浪費 30-100 行
- **Low**: マイナーな最適化機会、コンテキスト浪費 30 行未満

## Effort Definition

- **Low**: 1-2 行の修正、セクション削除、単純な統合
- **Medium**: セクション追加、5-10 行の修正、ファイル間の構造調整
- **High**: 大規模な構造変更、複数ファイルの調整、新規エージェント設計

## 検出戦略の共通パターン

### 2 フェーズアプローチ

**Phase 1: Comprehensive Problem Detection**
- 目的: 組織化やフォーマットを気にせず、すべての問題を網羅的に検出する
- 出力: 構造化されていない、包括的な問題リスト（箇条書き）

**Phase 2: Organization & Reporting**
- 目的: Phase 1 で検出した問題を整理し、優先順位付けされたレポートにする
- 出力: Severity でソートされた、構造化された findings レポート

### Adversarial Thinking

検出時は「指示に技術的には従いつつ、低品質な出力を生成しようとするエージェント実装者」の視点を採用する。

以下の adversarial questions を各検出戦略で使用する:
- "Can I technically satisfy this instruction while producing poor output?"
- "Can I claim to fulfill this requirement while actually doing something completely different?"
- "Does this instruction allow me to choose the easiest interpretation when ambiguous?"
- "Can I point to this instruction and explain what specific behavior it adds that wouldn't happen without it?"
```

### Step 10: I-6 次元エージェント定義ファイルの共通説明削除（7ファイル）
**対象ファイル**: agents/shared/instruction-clarity.md, agents/evaluator/criteria-effectiveness.md, agents/evaluator/scope-alignment.md, agents/evaluator/detection-coverage.md, agents/producer/workflow-completeness.md, agents/producer/output-format.md, agents/unclassified/scope-alignment.md
**変更内容**:

#### instruction-clarity.md
- 行26-28（Analysis Process セクション）: 詳細説明を削除し、共通ルール参照に置き換え
```markdown
**Analysis Process - Detection-First, Reporting-Second**:

Conduct your review in two distinct phases: first detect all problems comprehensively (including adversarially), then organize and report them. Refer to `.claude/skills/agent_audit_new/agents/shared/common-rules.md` for the 2-phase approach details, severity rules, and adversarial thinking guidance.
```
- 行153-157（Severity Rules セクション）: 削除し、共通ルール参照に置き換え
```markdown
### Severity Rules

Refer to `.claude/skills/agent_audit_new/agents/shared/common-rules.md` for severity definitions.

For this dimension:
```
（dimension-specific severity examples を記載する場合はこの後に追記）

#### criteria-effectiveness.md
- 行25-27: 同様に置き換え
- 行126-131: Severity Rules セクションを共通ルール参照に置き換え

#### scope-alignment.md (evaluator)
- 同様のパターンで Analysis Process と Severity Rules セクションを置き換え

#### detection-coverage.md
- 同様のパターンで Analysis Process と Severity Rules セクションを置き換え

#### workflow-completeness.md
- 同様のパターンで Analysis Process と Severity Rules セクションを置き換え

#### output-format.md
- 同様のパターンで Analysis Process と Severity Rules セクションを置き換え

#### scope-alignment.md (unclassified)
- 同様のパターンで Analysis Process と Severity Rules セクションを置き換え

### Step 11: I-7 Phase 2 Step 1 の findings 抽出をサブエージェントに委譲
**対象ファイル**: SKILL.md
**変更内容**:
- 行146-150（Phase 2 Step 1）: findings 抽出をサブエージェントに委譲する方式に変更
```markdown
#### Step 1: Findings の収集

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "haiku"`）:

> Phase 1 で成功した全次元の findings ファイル（`.agent_audit/{agent_name}/audit-*.md`）を Read し、severity が critical または improvement の finding（`###` ブロック単位）を抽出してください。
>
> 以下のフォーマットで返答してください:
> ```
> total: {N}
> critical: {M}
> improvement: {K}
>
> | # | ID | severity | title | 次元 |
> |---|-----|----------|-------|------|
> | 1 | {ID} | {severity} | {title} | {次元名} |
> ...
> ```

サブエージェント完了後、返答内容をテキスト出力として表示する。
`{total}` = 対象 finding の合計件数（返答から抽出）。
```

## 新規作成ファイル
| ファイル | 目的 | 対応 Step |
|---------|------|----------|
| agents/shared/common-rules.md | Severity Rules, Impact/Effort 定義、2 フェーズアプローチ、Adversarial Thinking 等の共通説明セクションを集約 | Step 9 |

## 削除推奨ファイル
なし
