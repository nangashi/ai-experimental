# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 2 Step 4 検証の閾値判定基準を明示 | I-1: 曖昧表現: Phase 2 Step 4 検証の閾値判定 |
| 2 | SKILL.md | 修正 | Phase 1 エラーハンドリングの「空」判定基準を明示 | I-2: 曖昧表現: Phase 1 エラーハンドリングの「空」判定 |
| 3 | SKILL.md | 修正 | Phase 2 Step 2a の "Other" 選択肢の記述を削除 | I-3: 曖昧表現: Phase 2 Step 2 「修正して承認」の処理 |

## 各ファイルの変更詳細

### 1. /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_audit_new/SKILL.md（修正）
**対応フィードバック**: I-1: 曖昧表現: Phase 2 Step 4 検証の閾値判定 [stability]

**変更内容**:
- 行258の検証ステップ4:
  - 現在: 「抽出したキーワードが `{agent_path}` の内容に存在するかを簡易チェックする（Grep または文字列検索）。全キーワードの 80% 以上が存在すれば変更適用成功とみなす」
  - 改善後: 「抽出したキーワードが `{agent_path}` の内容に存在するかを簡易チェックする。キーワード総数は全承認 findings から抽出した変更対象セクション名・フィールド名の統合集合とし、Grep で部分一致検索を実施する。全キーワードの 80% 以上が存在すれば変更適用成功とみなす」

### 2. /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_audit_new/SKILL.md（修正）
**対応フィードバック**: I-2: 曖昧表現: Phase 1 エラーハンドリングの「空」判定 [stability]

**変更内容**:
- 行134のエラーハンドリング基準:
  - 現在: 「対応する findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）が存在し、空でない → 成功」
  - 改善後: 「対応する findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）が存在し、ファイルサイズが 10 バイト以上かつ `## Summary` または `### {ID_PREFIX}-` セクションが 1 つ以上含まれる → 成功」

### 3. /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_audit_new/SKILL.md（修正）
**対応フィードバック**: I-3: 曖昧表現: Phase 2 Step 2 「修正して承認」の処理 [stability]

**変更内容**:
- 行194の "Other" 参照を削除:
  - 現在: 「続けて `AskUserQuestion` で方針確認（選択肢は以下の4つ。ユーザーが "Other" で修正内容をテキスト入力した場合は「修正して承認」として扱い、改善計画に含める）」
  - 改善後: 「続けて `AskUserQuestion` で方針確認（選択肢は以下の4つ）」

## 新規作成ファイル
（なし）

## 削除推奨ファイル
（なし）

## 実装順序
1. I-3（行194）: "Other" 選択肢の記述削除 - 単純な削除のみで他に影響なし
2. I-2（行134）: Phase 1 エラーハンドリングの判定基準明示 - Phase 1 の独立したロジック
3. I-1（行258）: Phase 2 検証の閾値判定基準明示 - Phase 2 の独立したロジック

依存関係の検出方法:
- 3つの変更は全て SKILL.md の異なるフェーズの記述であり、相互依存関係なし
- 行番号順に近い順（小→大）で実施することで、Edit ツールでの行番号ずれリスクを最小化

## 注意事項
- 変更によって既存のワークフローが壊れないこと
- Phase 1 エラーハンドリングの判定基準変更により、ヘッダのみのファイルが「失敗」として扱われることを確認すること
- Phase 2 検証の閾値判定基準明示により、キーワード抽出と Grep 実行の具体的な処理が実装時に明確になること
