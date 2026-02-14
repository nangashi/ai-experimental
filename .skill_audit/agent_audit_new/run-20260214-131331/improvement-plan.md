# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 0 Step 6 の冪等性保証処理追加、Phase 0 Step 2/4 の不要な全文保持削除、Phase 1 サブエージェントプロンプト変更（common-rules.md パス変数渡しに変更）、Phase 2 Step 2 に findings-summary.md の Read 処理追加 | I-1, I-2, I-3, I-4 |
| 2 | agents/evaluator/criteria-effectiveness.md | 修正 | 冒頭に common-rules.md の Read 指示追加 | I-2 |
| 3 | agents/evaluator/scope-alignment.md | 修正 | 冒頭に common-rules.md の Read 指示追加 | I-2 |
| 4 | agents/evaluator/detection-coverage.md | 修正 | 冒頭に common-rules.md の Read 指示追加 | I-2 |
| 5 | agents/producer/workflow-completeness.md | 修正 | 冒頭に common-rules.md の Read 指示追加 | I-2 |
| 6 | agents/producer/output-format.md | 修正 | 冒頭に common-rules.md の Read 指示追加 | I-2 |
| 7 | agents/shared/instruction-clarity.md | 修正 | 冒頭に common-rules.md の Read 指示追加 | I-2 |
| 8 | agents/unclassified/scope-alignment.md | 修正 | 冒頭に common-rules.md の Read 指示追加 | I-2 |

## 変更ステップ

### Step 1: I-1: frontmatter チェックの冪等性不明瞭 [stability]
**対象ファイル**: SKILL.md
**変更内容**:
- SKILL.md 行114: `6. 出力ディレクトリを作成する: ＜既存＞` → `6. 既存 findings ファイルの削除と出力ディレクトリの作成:`
- SKILL.md 行114-115:
```
   - Phase 1 の各サブエージェントは既存の findings ファイルを Write で上書きする（再実行時は前回の findings は削除される）
```
を削除
- SKILL.md 行114 の後に以下を追加:
```
   - 既存 findings ファイルを削除: `rm -f .agent_audit/{agent_name}/audit-*.md`（冪等性保証）
   - 出力ディレクトリを作成: `mkdir -p .agent_audit/{agent_name}/`
```

### Step 2: I-3: agent_content 変数の未使用 [efficiency]
**対象ファイル**: SKILL.md
**変更内容**:
- SKILL.md 行45: `- ＜agent_content 変数定義＞` を削除
- SKILL.md 行89: `2. Read で ＜agent_path＞ のファイルを読み込んで内容を確認する。` → `2. Read で ＜agent_path＞ のファイル存在確認を行う。`
- SKILL.md 行90: `3. ファイル内容の簡易チェック: ＜agent_path＞ を Read で読み込み、` → `3. YAML frontmatter チェック: ＜agent_path＞ を Read で読み込み、`
- SKILL.md 行94: `4. ＜agent_path＞ を Read で読み込み、内容を分析して` → `4. ＜agent_path＞ を Read で読み込んでグループ分類。内容を分析して`
- SKILL.md 行52-57 の「コンテキスト節約の原則」セクションに以下の注釈を追加:
```
4. **親コンテキストはエージェント定義の全文を保持しない**（サブエージェントが直接 Read する）
```

### Step 3: I-2: common-rules.md の埋め込み削減 [efficiency]
**対象ファイル**: SKILL.md, agents/evaluator/criteria-effectiveness.md, agents/evaluator/scope-alignment.md, agents/evaluator/detection-coverage.md, agents/producer/workflow-completeness.md, agents/producer/output-format.md, agents/shared/instruction-clarity.md, agents/unclassified/scope-alignment.md
**変更内容**:
- SKILL.md 行146-194: 行148-194（common-rules.md の全文埋め込み）を削除し、以下に置き換え:
```
> `.claude/skills/agent_audit_new/agents/{dim_path}.md` を Read し、その指示に従って分析を実行してください。
>
> パス変数:
> - `{agent_path}`: `{実際の agent_path の絶対パス}`（分析対象エージェント定義ファイル）
> - `{findings_save_path}`: `{実際の .agent_audit/{agent_name}/audit-{ID_PREFIX}.md の絶対パス}`（findings 保存先）
> - `{agent_name}`: `{実際の agent_name}`
> - `{common_rules_path}`: `.claude/skills/agent_audit_new/agents/shared/common-rules.md`（共通ルール定義）
>
> 分析完了後、以下のフォーマットで返答してください: `dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`
```
- SKILL.md 行196-199 を削除（重複情報）

- agents/evaluator/criteria-effectiveness.md 行14 の前（`## Task` の直前）に以下を追加:
```
## 前提: 共通ルール定義の読み込み

**必須**: 分析開始前に `{common_rules_path}` を Read で読み込み、以下の定義を参照してください:
- Severity Rules (critical / improvement / info の判定基準)
- Impact Definition / Effort Definition
- 検出戦略の共通パターン（2 フェーズアプローチ、Adversarial Thinking）

```

- agents/evaluator/scope-alignment.md, agents/evaluator/detection-coverage.md, agents/producer/workflow-completeness.md, agents/producer/output-format.md, agents/shared/instruction-clarity.md, agents/unclassified/scope-alignment.md の各ファイルにも同様に、`## Task` セクションの直前（frontmatter の後、本文の先頭）に上記と同じ「## 前提: 共通ルール定義の読み込み」セクションを追加

### Step 4: I-4: 欠落ステップ: findings-summary.md の未読取り [effectiveness]
**対象ファイル**: SKILL.md
**変更内容**:
- SKILL.md 行236: `findings の詳細は ＜.agent_audit/{agent_name}/findings-summary.md＞ を Read で読み込み、テキスト出力として表示する。` を以下に変更:
```
Read で `.agent_audit/{agent_name}/findings-summary.md` を読み込み、findings の詳細をテキスト出力として表示する。
```
- SKILL.md 行240（`#### Step 2: 一覧提示 + 承認方針の選択`）の直後、行242（`対象 findings の一覧をテキスト出力する:`）の前に以下を挿入:
```

findings-summary.md から読み込んだ内容を基に、対象 findings の一覧をテキスト出力する:
```

## 新規作成ファイル

なし

## 削除推奨ファイル

なし
