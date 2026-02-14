# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 1B 外部参照削除、Phase 1 返答フォーマット明示、Phase 2 Step 2 一覧表示削除、Phase 2 Step 2a "Other" 処理削除、findings 抽出方法明記、Phase 0 Step 7a 冪等性明示、次元パス解決ルール追記、Phase 2 検証ステップ拡張 | C-1, I-3, I-4, I-6, I-7, I-8, I-9, I-5 |
| 2 | agents/shared/instruction-clarity.md | 修正 | Phase 2 セクション削除、Antipattern Catalog を共通ファイルへの参照に置換 | I-1, I-2 |
| 3 | agents/evaluator/criteria-effectiveness.md | 修正 | Phase 2 セクション削除、Antipattern Catalog を共通ファイルへの参照に置換 | I-1, I-2 |
| 4 | agents/evaluator/scope-alignment.md | 修正 | Phase 2 セクション削除、Antipattern Catalog を共通ファイルへの参照に置換 | I-1, I-2 |
| 5 | agents/evaluator/detection-coverage.md | 修正 | Phase 2 セクション削除、Antipattern Catalog を共通ファイルへの参照に置換 | I-1, I-2 |
| 6 | agents/producer/workflow-completeness.md | 修正 | Phase 2 セクション削除、Antipattern Catalog を共通ファイルへの参照に置換 | I-1, I-2 |
| 7 | agents/producer/output-format.md | 修正 | Phase 2 セクション削除、Antipattern Catalog を共通ファイルへの参照に置換 | I-1, I-2 |
| 8 | agents/unclassified/scope-alignment.md | 修正 | Phase 2 セクション削除、Antipattern Catalog を共通ファイルへの参照に置換 | I-1, I-2 |
| 9 | antipatterns/instruction-clarity.md | 新規作成 | IC 次元の Antipattern Catalog を外部化 | I-2 |
| 10 | antipatterns/criteria-effectiveness.md | 新規作成 | CE 次元の Antipattern Catalog を外部化 | I-2 |
| 11 | antipatterns/scope-alignment.md | 新規作成 | SA 次元の Antipattern Catalog を外部化 | I-2 |
| 12 | antipatterns/detection-coverage.md | 新規作成 | DC 次元の Antipattern Catalog を外部化 | I-2 |
| 13 | antipatterns/workflow-completeness.md | 新規作成 | WC 次元の Antipattern Catalog を外部化 | I-2 |
| 14 | antipatterns/output-format.md | 新規作成 | OF 次元の Antipattern Catalog を外部化 | I-2 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**:
- C-1: スキル外ファイル参照 [architecture]
- I-3: Phase 1 サブエージェント返答フォーマット指示の明確化 [stability]
- I-4: Phase 2 Step 2 の findings 一覧テーブルの取得元明示 [stability]
- I-6: Phase 2 Step 2a の "Other" 入力処理の曖昧性解消 [stability]
- I-7: Phase 2 Step 2 テキスト出力の統合 [efficiency]
- I-8: Phase 0 Step 7a の冪等性意図の明示 [stability]
- I-9: 次元エージェントパスの定義補完 [stability]
- I-5: 成果物の構造検証追加 [architecture]

**変更内容**:

#### 変更1: 174行の agent_bench 外部参照を削除 (C-1)
- **現在の記述**: 174行に「`.agent_audit/{agent_name}/audit-*.md`（agent_bench スキルとの連携用、ただし存在しない場合は空として扱われるため必須依存ではない）」との記載
- **改善後の記述**: この記述を削除。agent_bench スキルは agent_audit の出力ディレクトリから findings を参照するが、agent_audit 側からの参照は不要

#### 変更2: 136-139行のサブエージェント返答フォーマットを明確化 (I-3)
- **現在の記述**:
  ```
  > 分析完了後、以下のフォーマットで返答してください: `dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`
  ```
- **改善後の記述**:
  ```
  > 分析完了後、以下の1行フォーマット**のみ**で返答してください（他の出力を含めないこと）: `dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`
  ```

#### 変更3: 108-113行に次元パス解決ルールを追記 (I-9)
- **現在の記述**: dimensions テーブルに `shared/instruction-clarity` 等のパスのみ記載
- **改善後の記述**: テーブルの直後に以下を追記:
  ```
  各 `dim_path` は `.claude/skills/agent_audit_new/agents/{dim_path}.md` として解決される。
  ```

#### 変更4: 173-180行の Step 2 一覧表示を削除し、Step 2a で findings を直接抽出 (I-4, I-7)
- **現在の記述**:
  ```markdown
  #### Step 2: 一覧提示 + 承認方針の選択

  対象 findings の一覧をテキスト出力する:
  ```
  ### 対象 findings: 計{total}件（critical {N}, improvement {M}）
  | # | ID | severity | title | 次元 |
  |---|-----|----------|-------|------|
  | 1 | {ID} | {severity} | {title} | {次元名} |
  ...
  ```

  続けて `AskUserQuestion` で承認方針を確認:
  ```
- **改善後の記述**:
  ```markdown
  #### Step 2: 承認方針の選択

  findings ファイルを Read し、各 finding の ID, severity, title を抽出する。抽出方法:
  - findings ファイル形式: `### {ID}: {title} [severity: {level}]`
  - ID: `###` 見出しの最初の部分（例: `CE-01`）
  - severity: `[severity: {level}]` の {level} 部分（critical/improvement/info）
  - title: ID と severity の間の文字列
  - 次元名: findings ファイル名から導出（例: `audit-CE.md` → CE 次元）

  対象 findings の集計結果をテキスト出力: `計{total}件（critical {N}, improvement {M}）`

  `AskUserQuestion` で承認方針を確認:
  ```

#### 変更5: 200行の "Other" 処理記述を削除 (I-6)
- **現在の記述**:
  ```
  続けて `AskUserQuestion` で方針確認（選択肢は以下の4つ。ユーザーが "Other" で修正内容をテキスト入力した場合は「修正して承認」として扱い、改善計画に含める）:
  ```
- **改善後の記述**:
  ```
  続けて `AskUserQuestion` で方針確認（選択肢は以下の4つ）:
  ```

#### 変更6: 102行の冪等性意図を明示 (I-8)
- **現在の記述**:
  ```
  7a. 既存の findings ファイルを削除する: `rm -f .agent_audit/{agent_name}/audit-*.md` を Bash で実行する（Phase 1の再実行時に重複を防ぐ）
  ```
- **改善後の記述**:
  ```
  7a. 既存の findings ファイルを削除する: `rm -f .agent_audit/{agent_name}/audit-*.md` を Bash で実行する（Phase 1の再実行時に重複を防ぐため、冪等性を保証する）
  ```

#### 変更7: 249-256行の検証ステップに成果物構造検証を追加 (I-5)
- **現在の記述**:
  ```
  #### 検証ステップ

  改善適用完了後、以下の検証を実行する:

  1. Read で `{agent_path}` を再読み込み
  2. YAML frontmatter の存在確認（ファイル先頭が `---` で始まり、`description:` を含む）
  3. 検証成功時: 「✓ 検証完了: エージェント定義の構造は正常です」とテキスト出力
  4. 検証失敗時: ...
  ```
- **改善後の記述**:
  ```
  #### 検証ステップ

  改善適用完了後、以下の検証を実行する:

  1. Read で `{agent_path}` を再読み込み
  2. **構造検証**: 以下を確認する:
     - YAML frontmatter の存在（ファイル先頭が `---` で始まり、`description:` を含む）
  3. Read で `.agent_audit/{agent_name}/audit-approved.md` を読み込み、成果物の構造を検証:
     - 必須セクションの存在: `# 承認済み監査 Findings`, `承認: N/M件`, `## 重大な問題` または `## 改善提案`
     - finding ID 形式: 各 finding が `### {ID}: {title} [{次元名}]` 形式で記述されているか
     - finding ID 重複がないか
  4. 検証成功時: 「✓ 検証完了: エージェント定義と成果物の構造は正常です」とテキスト出力
  5. 検証失敗時: 「✗ 検証失敗: 以下の問題が検出されました: {問題リスト}」とテキスト出力し、AskUserQuestion で「ロールバックしますか？（`cp {backup_path} {agent_path}` を実行）」を確認する。「はい」選択時は Bash でロールバック実行後、Phase 3 で警告を表示して終了。「いいえ」選択時は Phase 3 で警告のみ表示
  ```

---

### 2. agents/shared/instruction-clarity.md（修正）
**対応フィードバック**:
- I-1: 次元エージェント定義の Phase 2 セクション統合 [efficiency]
- I-2: 次元エージェント定義の Antipattern Catalog 統合 [efficiency]

**変更内容**:

#### 変更1: "Phase 2: Organization & Reporting" セクション全体を削除 (I-1)
- **現在の記述**: 148-195行に Phase 2 セクションが存在
- **改善後の記述**: このセクションを完全に削除（severity 分類、finding ID prefix、output format は次のセクションに統合済み）

#### 変更2: Detection Strategy 5 の Antipattern Catalog 詳細を外部参照に置換 (I-2)
- **現在の記述**: 115-145行に Antipattern Catalog の詳細（Role Definition Antipatterns, Context Antipatterns 等）
- **改善後の記述**:
  ```markdown
  ### Detection Strategy 5: Antipattern Catalog

  **Antipattern Catalog**: `.claude/skills/agent_audit_new/antipatterns/instruction-clarity.md` を Read し、カタログに記載されたアンチパターンを確認する。

  各アンチパターンに該当する箇所を検出し、Phase 1 の包括的問題リストに追加する。
  ```

---

### 3-8. agents/evaluator/criteria-effectiveness.md, agents/evaluator/scope-alignment.md, agents/evaluator/detection-coverage.md, agents/producer/workflow-completeness.md, agents/producer/output-format.md, agents/unclassified/scope-alignment.md（修正）
**対応フィードバック**:
- I-1: 次元エージェント定義の Phase 2 セクション統合 [efficiency]
- I-2: 次元エージェント定義の Antipattern Catalog 統合 [efficiency]

**変更内容**（全ファイル共通）:

#### 変更1: "Phase 2: Organization & Reporting" セクション全体を削除 (I-1)
- **改善後の記述**: Phase 2 セクションを完全に削除（SKILL.md が Phase 2 処理を統一管理）

#### 変更2: "Detection Strategy X: Antipattern Catalog" セクションを外部参照に置換 (I-2)
- **現在の記述**: 各次元エージェントに Antipattern Catalog 詳細が記述されている
- **改善後の記述**:
  ```markdown
  ### Detection Strategy X: Antipattern Catalog

  **Antipattern Catalog**: `.claude/skills/agent_audit_new/antipatterns/{dimension-name}.md` を Read し、カタログに記載されたアンチパターンを確認する。

  各アンチパターンに該当する箇所を検出し、Phase 1 の包括的問題リストに追加する。
  ```

  注: `{dimension-name}` は各次元に応じて以下に置換:
  - criteria-effectiveness
  - scope-alignment
  - detection-coverage
  - workflow-completeness
  - output-format

---

## 新規作成ファイル

### 9. antipatterns/instruction-clarity.md（新規作成）
**目的**: IC 次元の Antipattern Catalog を外部化し、次元エージェント定義のコンテキスト消費を削減

**ファイル内容**:
```markdown
# Instruction Clarity Antipattern Catalog

以下は IC 次元で検出すべき既知のアンチパターンです。

## Role Definition Antipatterns

### Role Absence
- **定義**: ロール/ペルソナ定義が存在しない、またはタスクから推測する必要がある
- **検出方法**: ファイル先頭3文で明示的なロール定義が存在しない

### Generic Role
- **定義**: 過度に広範な用語（"specialist", "agent"）でロールを定義し、ドメイン専門性が不明
- **検出方法**: ロール定義に具体的なドメイン用語（"security auditor", "API designer" 等）が欠如

### Delayed Role Introduction
- **定義**: ロール定義が手続き的セクションの後に登場
- **検出方法**: ロール定義が "## Task" や "## Steps" セクションより後に出現

## Context Antipatterns

### Implicit Context
- **定義**: "refer to the template", "use the standard format" 等のファイルパスや明示的定義なしの参照
- **検出方法**: "refer to", "see", "use", "follow" を含む文でファイルパスやセクション名が不在

### Missing Defaults
- **定義**: 曖昧な入力、ファイル不在、エッジケースに対する指定動作なし
- **検出方法**: エラーハンドリングや条件分岐で "else" 句やデフォルト動作の記述なし

### Assumed Knowledge
- **定義**: 未記述のコンテキストに依存する指示（"follow best practices" を定義なしで使用）
- **検出方法**: "best practices", "standard methods", "industry standards" を定義なしで参照

## Structural Antipatterns

### Scattered Constraints
- **定義**: 制約が複数セクションに分散し、統一的なクロスリファレンスなし
- **検出方法**: "constraint", "must not", "should not" が異なるセクションに出現し、相互参照なし

### Constraints After Actions
- **定義**: 重要な制約が、それが支配するアクション指示の後に配置（同一論理セクション内）
- **検出方法**: "## Task" セクション内でアクション指示の後に制約セクションが出現

### Exceptions Before Rules
- **定義**: 例外ケースやエッジケースが、それが修飾する一般ルールより前にリスト化
- **検出方法**: "exception", "edge case", "special case" が対応する一般ルールより前に出現

### Detail Before Overview
- **定義**: 手続き的ステップや技術詳細が高レベルの目的やコンテキストより前に登場
- **検出方法**: "## Steps" や "## Task" が "## Overview" や目的記述より前に出現

## Meta-Instruction Antipatterns

### Contradictory Instructions
- **定義**: 異なるセクションが同一トピックに対して矛盾する指示を提供
- **検出方法**: 同一概念に対して相反する要求を検出（手動確認）

### Circular Instructions
- **定義**: 自己参照する指示で運用詳細を追加しない（例: "be clear" を明確性の定義なしで使用）
- **検出方法**: "be clear", "ensure quality", "be thorough" 等の自己参照的指示

## Effectiveness Antipatterns

### Default Restatement
- **定義**: モデルのデフォルト動作を繰り返す指示（"be thorough", "think carefully", "analyze comprehensively"）
- **検出方法**: 上記フレーズの出現

### Aspirational Without Mechanism
- **定義**: 達成方法を指定せずに望ましい結果を記述（"ensure high-quality output", "produce actionable insights"）
- **検出方法**: "ensure", "produce", "achieve" を具体的な手順なしで使用

### Unfiltered Reporting
- **定義**: 優先順位付けやフィルタリング基準なしで網羅的報告を要求（"report all issues found", "list every potential problem"）
- **検出方法**: "all", "every", "complete list" を判定基準なしで使用

### Capability Restriction
- **定義**: 過度に規範的な手順で、文脈に応じた判断が有益な場面でモデルの適用を妨げる
- **検出方法**: "must", "always", "never" の過剰使用（例外条件なし）

### Redundant Emphasis
- **定義**: 強調のため異なる表現で同一指示を複数セクションに繰り返し（新情報なし）
- **検出方法**: 意味的に70%以上重複する指示が異なるセクションに出現
```

### 10. antipatterns/criteria-effectiveness.md（新規作成）
**目的**: CE 次元の Antipattern Catalog を外部化

**ファイル内容**: criteria-effectiveness.md の該当セクション（82-116行）から抽出

### 11. antipatterns/scope-alignment.md（新規作成）
**目的**: SA 次元の Antipattern Catalog を外部化

**ファイル内容**: scope-alignment.md の該当セクション（Antipattern Catalog 部分）から抽出

### 12. antipatterns/detection-coverage.md（新規作成）
**目的**: DC 次元の Antipattern Catalog を外部化

**ファイル内容**: detection-coverage.md の該当セクションから抽出

### 13. antipatterns/workflow-completeness.md（新規作成）
**目的**: WC 次元の Antipattern Catalog を外部化

**ファイル内容**: workflow-completeness.md の該当セクション（101-132行）から抽出

### 14. antipatterns/output-format.md（新規作成）
**目的**: OF 次元の Antipattern Catalog を外部化

**ファイル内容**: output-format.md の該当セクションから抽出

## 削除推奨ファイル
なし

## 実装順序

1. **antipatterns/*.md（9-14）を新規作成** — 各次元エージェントが参照する共通ファイル。エージェント定義の変更前に作成する必要がある
2. **agents/*.md（2-8）の Antipattern Catalog 参照を置換** — Phase 2 セクションを削除し、Antipattern Catalog を外部参照に置換
3. **SKILL.md（1）を修正** — 外部参照削除、返答フォーマット明示、Step 2 一覧削除、検証拡張等の全変更を適用

依存関係の検出方法:
- 改善1（antipatterns 新規作成）の成果物（新規ファイル）を改善2（agents 参照置換）が参照する → 改善1が先
- 改善2（agents 修正）は改善3（SKILL.md 修正）と独立 → 改善2完了後に改善3を実施

## 注意事項
- 変更によって既存のワークフローが壊れないこと
- Antipattern Catalog 外部化により、次元エージェントファイルの平均行数が約180行から約120行に削減される（コンテキスト消費33%削減）
- Phase 2 処理が SKILL.md に一元化され、次元エージェントの責務が Phase 1（検出）のみに明確化される
- SKILL.md の検証ステップ拡張により、成果物の構造妥当性が保証される
- 次元パス解決ルールの明示により、次元エージェント追加時の曖昧さが解消される
