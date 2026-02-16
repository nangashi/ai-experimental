# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 3 の直接指示をテンプレートファイルに外部化 | I-1: architecture |
| 2 | templates/perspective/critic-effectiveness.md | 修正 | 出力方式を SendMessage から返答受信に明確化 | I-2: stability |
| 3 | templates/perspective/critic-completeness.md | 修正 | 出力方式を SendMessage から返答受信に明確化 | I-2: stability |
| 4 | templates/perspective/critic-clarity.md | 修正 | 出力方式を SendMessage から返答受信に明確化 | I-2: stability |
| 5 | templates/perspective/critic-generality.md | 修正 | 出力方式を SendMessage から返答受信に明確化 | I-2: stability |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**: I-1: Phase 3 評価実行の直接指示が7行を超えている

**変更内容**:
- **Phase 3: 並列評価実行のサブエージェント指示（219-227行）**: 現在は9行の直接指示 → テンプレートファイルに外部化し、1行の参照に置き換え

**変更前（219-227行）**:
```markdown
```
以下の手順でタスクを実行してください:

1. Read で {prompt_path} を読み込み、その内容に従ってタスクを実行してください
2. Read で {test_doc_path} を読み込み、処理対象としてください
3. 処理結果を Write で {result_path} に保存してください
4. 最後に「保存完了: {result_path}」とだけ返答してください
```
```

**変更後**:
```markdown
`.claude/skills/agent_bench_new/templates/phase3-evaluation.md` を Read で読み込み、その内容に従って処理を実行してください。
```

### 2-5. templates/perspective/critic-effectiveness.md, critic-completeness.md, critic-clarity.md, critic-generality.md（修正）
**対応フィードバック**: I-2: perspective critic テンプレートの変数不整合

**変更内容**:
- **出力指示セクション**: 「SendMessage を使ってコーディネーターに報告してください」→「以下の形式で返答してください」に統一し、TaskUpdate 指示を削除

#### 2. templates/perspective/critic-effectiveness.md

**変更前（36-52行）**:
```markdown
## 出力フォーマット

以下の形式で SendMessage を使ってコーディネーターに報告してください:

```
### 有効性批評結果

#### 重大な問題（観点の根本的な再設計が必要）
- [問題]: [理由]
（なければ「なし」）

#### 改善提案（品質向上に有効）
- [提案]: [理由]
（なければ「なし」）

#### 確認（良い点）
- [評価点]
```
```

**変更後**:
```markdown
## 出力フォーマット

以下の形式で返答してください:

```
### 有効性批評結果

#### 重大な問題（観点の根本的な再設計が必要）
- [問題]: [理由]
（なければ「なし」）

#### 改善提案（品質向上に有効）
- [提案]: [理由]
（なければ「なし」）

#### 確認（良い点）
- [評価点]
```
```

**変更前（74行）**:
```markdown
3. TaskUpdate で {task_id} を completed にする
```

**変更後**:
（削除）

#### 3. templates/perspective/critic-completeness.md

**変更前（88-103行）**:
```markdown
## Output Guidelines

Report your findings to the coordinator using SendMessage in this format:

**Critical Issues** - Problems that would prevent essential omission detection (if none, state "None")

**Missing Element Detection Evaluation** - Table with 5+ rows:
| Essential Design Element | Detectable if Missing | Evidence | Improvement Proposal |
|-------------------------|----------------------|----------|---------------------|

**Problem Bank Improvement Proposals** - Specific additions needed (if none, state "None")

**Other Improvement Proposals** - Additional recommendations (if none, state "None")

**Positive Aspects** - Well-designed elements worth confirming
```

**変更後**:
```markdown
## Output Guidelines

Report your findings in this format:

**Critical Issues** - Problems that would prevent essential omission detection (if none, state "None")

**Missing Element Detection Evaluation** - Table with 5+ rows:
| Essential Design Element | Detectable if Missing | Evidence | Improvement Proposal |
|-------------------------|----------------------|----------|---------------------|

**Problem Bank Improvement Proposals** - Specific additions needed (if none, state "None")

**Other Improvement Proposals** - Additional recommendations (if none, state "None")

**Positive Aspects** - Well-designed elements worth confirming
```

**変更前（104-106行）**:
```markdown
## Task Completion

After sending your report, mark {task_id} as completed using TaskUpdate.
```

**変更後**:
（削除）

#### 4. templates/perspective/critic-clarity.md

**変更前（56-73行）**:
```markdown
## 出力フォーマット

以下の形式で SendMessage を使ってコーディネーターに報告してください:

```
### 明確性批評結果

#### 重大な問題（AIの動作に大きなブレが生じる）
- [問題箇所]: [曖昧な表現/不明確な基準] → [改善案]
（なければ「なし」）

#### 改善提案
- [提案]: [理由]
（なければ「なし」）

#### 確認（良い点）
- [評価点]
```

3. TaskUpdate で {task_id} を completed にする
```

**変更後**:
```markdown
## 出力フォーマット

以下の形式で返答してください:

```
### 明確性批評結果

#### 重大な問題（AIの動作に大きなブレが生じる）
- [問題箇所]: [曖昧な表現/不明確な基準] → [改善案]
（なければ「なし」）

#### 改善提案
- [提案]: [理由]
（なければ「なし」）

#### 確認（良い点）
- [評価点]
```
```

#### 5. templates/perspective/critic-generality.md

**変更前（50-79行）**:
```markdown
## Output Format

Report using SendMessage:

```
### Generality Critique Results

#### Critical Issues (Domain over-dependency)
- [Issue]: [Reason]
(If none, "None")

#### Scope Item Generality
| Item | Classification | Failed Dimensions | Proposal |
|------|----------------|------------------|----------|
| {1} | Generic/Conditional/Domain-Specific | Industry/Regulation/Tech Stack (if any) | ... |
| {2} | ... | ... | ... |
(5 rows)

#### Problem Bank Generality
- Generic: {N}
- Conditional: {N}
- Domain-Specific: {N} (list: ...)

#### Improvement Proposals
- [Proposal]: [Reason]
(If none, "None")

#### Positive Aspects
- [Observation]
```

TaskUpdate {task_id} to completed.
```

**変更後**:
```markdown
## Output Format

Report in this format:

```
### Generality Critique Results

#### Critical Issues (Domain over-dependency)
- [Issue]: [Reason]
(If none, "None")

#### Scope Item Generality
| Item | Classification | Failed Dimensions | Proposal |
|------|----------------|------------------|----------|
| {1} | Generic/Conditional/Domain-Specific | Industry/Regulation/Tech Stack (if any) | ... |
| {2} | ... | ... | ... |
(5 rows)

#### Problem Bank Generality
- Generic: {N}
- Conditional: {N}
- Domain-Specific: {N} (list: ...)

#### Improvement Proposals
- [Proposal]: [Reason]
(If none, "None")

#### Positive Aspects
- [Observation]
```
```

## 新規作成ファイル
| ファイル | 目的 | 対応フィードバック |
|---------|------|------------------|
| templates/phase3-evaluation.md | Phase 3 並列評価実行のサブエージェント指示を外部化 | I-1: architecture |

### templates/phase3-evaluation.md の内容
```markdown
以下の手順でタスクを実行してください:

1. Read で {prompt_path} を読み込み、その内容に従ってタスクを実行してください
2. Read で {test_doc_path} を読み込み、処理対象としてください
3. 処理結果を Write で {result_path} に保存してください
4. 最後に「保存完了: {result_path}」とだけ返答してください
```

## 削除推奨ファイル
（なし）

## 実装順序
1. **templates/phase3-evaluation.md を新規作成** — SKILL.md が参照するテンプレートファイルを先に作成する必要がある
2. **SKILL.md を修正** — Phase 3 のサブエージェント指示を新規テンプレートへの参照に置き換える（1に依存）
3. **templates/perspective/critic-*.md（4ファイル）を修正** — 出力方式を SendMessage から返答受信に統一（SKILL.md の修正と独立、並列実施可能）

## 注意事項
- Phase 3 のテンプレート外部化により、SKILL.md の行数が 390行 → 383行に削減される（7行削減）
- perspective critic テンプレートの修正は、SKILL.md Phase 0 Step 4 の「4つのサブエージェントの返答を受信し」という記述と整合する
- 既存のワークフローは変更なし（出力内容は同一、配送方式のみ明確化）
- 新規テンプレート `phase3-evaluation.md` のパス変数（`{prompt_path}`, `{test_doc_path}`, `{result_path}`）は SKILL.md Phase 3 で既に定義されており、追加の変数定義は不要
