# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | templates/perspective/critic-effectiveness.md | 修正 | TaskUpdate 指示の削除（74行） | stability: perspective critic テンプレートの TaskUpdate 指示残存 |
| 2 | templates/perspective/critic-completeness.md | 修正 | Task Completion セクションの削除（104-106行） | stability: perspective critic テンプレートの TaskUpdate 指示残存 |
| 3 | templates/perspective/critic-generality.md | 修正 | TaskUpdate 指示の削除（9行） | stability: perspective critic テンプレートの TaskUpdate 指示残存 |

## 各ファイルの変更詳細

### 1. templates/perspective/critic-effectiveness.md（修正）
**対応フィードバック**: stability: perspective critic テンプレートの TaskUpdate 指示残存

**変更内容**:
- 74行: `3. TaskUpdate で {task_id} を completed にする` を削除

**変更理由**:
SKILL.md Phase 0 Step 4 では「返答を受信し」という動作を前提としているため、サブエージェントが TaskUpdate を実行すると返答なしで完了してしまい、親エージェントが結果を受け取れない。他の critic テンプレート（critic-clarity.md）は既に TaskUpdate 指示を含んでいないため、整合性を取る必要がある。

### 2. templates/perspective/critic-completeness.md（修正）
**対応フィードバック**: stability: perspective critic テンプレートの TaskUpdate 指示残存

**変更内容**:
- 104-106行: `## Task Completion` セクション全体を削除
  ```markdown
  ## Task Completion

  After sending your report, mark {task_id} as completed using TaskUpdate.
  ```

**変更理由**:
SKILL.md Phase 0 Step 4 では批判レビュー結果を返答として受信することを前提としているため、TaskUpdate による完了処理はワークフローと不整合。critic-effectiveness.md, critic-generality.md と同様に削除して統一する。

### 3. templates/perspective/critic-generality.md（修正）
**対応フィードバック**: stability: perspective critic テンプレートの TaskUpdate 指示残存

**変更内容**:
- 9行: `4. Mark {task_id} as completed via TaskUpdate` を削除
- 8行を修正: `3. Report to coordinator via SendMessage` → `3. Report using the output format below`

**変更理由**:
SKILL.md Phase 0 Step 4 では返答ベースでの結果受信を前提としているため、TaskUpdate 指示を削除。また、このテンプレートには SendMessage による報告指示も含まれているが、他の critic テンプレート（effectiveness, completeness, clarity）はいずれも SendMessage を使用せず直接返答形式を採用しているため、統一性のために表現を修正する。

## 新規作成ファイル

（なし）

## 削除推奨ファイル

（なし）

## 実装順序

1. templates/perspective/critic-effectiveness.md — 74行の TaskUpdate 指示削除
2. templates/perspective/critic-completeness.md — 104-106行の Task Completion セクション削除
3. templates/perspective/critic-generality.md — 9行の TaskUpdate 指示削除、8行の表現修正

**依存関係**: なし（3ファイルは独立して変更可能）

## 注意事項

- 変更後、全ての perspective critic テンプレート（4種）が統一された動作様式となる:
  - TaskUpdate を使用しない
  - SendMessage を使用しない
  - 返答形式で結果を報告する
- SKILL.md Phase 0 Step 4 の「返答を受信し」という動作と整合性が保たれる
- 既存のワークフローに影響なし（critic-clarity.md は既にこの形式を採用済み）
