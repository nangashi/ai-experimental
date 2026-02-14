# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | 外部参照パス削除、目的の明確化、不可逆操作ガード追加、エラーハンドリング詳細化、検証ロジック強化 | C-1, C-2, C-3, C-4, I-1, I-2, I-3, I-4, I-5, I-8, I-9 |
| 2 | agents/evaluator/criteria-effectiveness.md | 修正 | 検出戦略セクションの圧縮（冗長な例示削除） | I-6 |
| 3 | agents/evaluator/scope-alignment.md | 修正 | 検出戦略セクションの圧縮（冗長な例示削除） | I-6 |
| 4 | agents/evaluator/detection-coverage.md | 修正 | 検出戦略セクションの圧縮（冗長な例示削除） | I-6 |
| 5 | agents/producer/workflow-completeness.md | 修正 | 検出戦略セクションの圧縮（冗長な例示削除） | I-6 |
| 6 | agents/producer/output-format.md | 修正 | 検出戦略セクションの圧縮（冗長な例示削除） | I-6 |
| 7 | agents/shared/instruction-clarity.md | 修正 | 検出戦略セクションの圧縮（冗長な例示削除） | I-6 |
| 8 | templates/apply-improvements.md | 修正 | 返答行数制約を追加（modified/skipped リスト上限） | I-7 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**:
- C-1: 外部参照の残存
- C-2: 目的の明確性
- C-3: バックアップ作成失敗時の処理
- C-4: agent_path上書き前の最終確認
- I-1: Phase 1 エラーハンドリングの findings ファイル内容抽出方法
- I-2: Phase 2 Step 2a の AskUserQuestion 選択肢
- I-3: Phase 0 Step 6 でディレクトリ作成時の既存確認
- I-4: Phase 2 Step 4 の検証ステップ
- I-5: Phase 2 Step 4 の部分失敗ハンドリング
- I-8: Phase 2 Step 2a での「残りすべて承認」の挙動
- I-9: 検証失敗時の次アクション

**変更内容**:
- 行6-10: スキル目的の定義 → 具体的な成果物と入出力で定義（対象: コンテンツ品質問題、入力: エージェント定義ファイル、出力: 静的分析 findings + 改善適用結果、成功基準: 曖昧な基準・スコープ不整合・実行不可能な指示を検出・修正すること）
- 行64: `.claude/skills/agent_audit/group-classification.md` への参照 → 「詳細は同一スキル内の `group-classification.md` を参照」に修正
- 行81: ディレクトリ作成コマンド → 「`mkdir -p .agent_audit/{agent_name}/` を実行する。既に存在する場合、既存の findings ファイルが上書きされる可能性があることに注意」に修正
- 行126: Summary セクション抽出方法 → 「`## Summary` セクション内の `- Total findings: {critical} critical, {improvement} improvement, {info} info` の行から抽出する。Summary セクションが不在または抽出失敗時は、findings ファイル内の `### {ID_PREFIX}-` で始まる行数から推定する」に具体化
- 行181: AskUserQuestion 選択肢 → 「選択肢: "Approve"（承認）、"Skip"（スキップ）、"Approve all remaining"（残りすべて承認）、"Cancel"（キャンセル）、"Other"（修正内容を入力）」に明示
- 行184: 「残りすべて承認」の挙動 → 「この指摘を含め、未確認の全指摘（critical と improvement の両方）を severity に関係なく承認としてループを終了する」に明確化
- 行217の直後に追加: 「バックアップ作成後、`test -f {backup_path}` で存在確認を行う。ファイルが存在しない場合、「✗ バックアップ作成に失敗しました。改善適用を中止します。」とエラー出力し、Phase 3 へ直行する」
- 行219の直前に追加: 「**最終確認**: 改善適用前に AskUserQuestion で最終確認を行う。選択肢: "Proceed"（続行）、"Cancel"（キャンセル）。キャンセル選択時は Phase 3 へ直行する」
- 行230-236: 検証ステップ → 「1. Read で `{agent_path}` を再読み込み、2. YAML frontmatter の存在確認、3. サブエージェント返答内の `modified:` 行を確認する。`modified: 0件` の場合は警告表示（「⚠ 改善が適用されませんでした。バックアップ: {backup_path}」）してバックアップ保持のまま Phase 3 へ進む、4. 検証成功時: 「✓ 検証完了」、検証失敗時: 「✗ 検証失敗: エージェント定義が破損している可能性があります。以下のコマンドでロールバックできます: `cp {backup_path} {agent_path}`」とテキスト出力し、スキルを終了する」に強化

### 2. agents/evaluator/criteria-effectiveness.md（修正）
**対応フィードバック**: I-6: dimension agent ファイルの行数が過大

**変更内容**:
- Detection Strategy セクション: 各戦略の説明を簡潔化し、冗長な例示を削減（目標: 約150行以下に圧縮）
- 重複する adversarial test の例を統合
- 具体例を最小限（各戦略1-2例）に削減

### 3. agents/evaluator/scope-alignment.md（修正）
**対応フィードバック**: I-6: dimension agent ファイルの行数が過大

**変更内容**:
- Detection Strategy セクション: 各戦略の説明を簡潔化し、冗長な例示を削減（目標: 約140行以下に圧縮）
- スコープ境界の例を最小限に統合

### 4. agents/evaluator/detection-coverage.md（修正）
**対応フィードバック**: I-6: dimension agent ファイルの行数が過大

**変更内容**:
- Detection Strategy セクション: 各戦略の説明を簡潔化し、冗長な例示を削減（目標: 約160行以下に圧縮）
- 検出戦略の例を統合

### 5. agents/producer/workflow-completeness.md（修正）
**対応フィードバック**: I-6: dimension agent ファイルの行数が過大

**変更内容**:
- Detection Strategy セクション: 各戦略の説明を簡潔化し、冗長な例示を削減（目標: 約150行以下に圧縮）
- ワークフローパターンの例を最小限に統合

### 6. agents/producer/output-format.md（修正）
**対応フィードバック**: I-6: dimension agent ファイルの行数が過大

**変更内容**:
- Detection Strategy セクション: 各戦略の説明を簡潔化し、冗長な例示を削減（目標: 約155行以下に圧縮）
- 出力形式の例を統合

### 7. agents/shared/instruction-clarity.md（修正）
**対応フィードバック**: I-6: dimension agent ファイルの行数が過大

**変更内容**:
- Detection Strategy セクション: 各戦略の説明を簡潔化し、冗長な例示を削減（目標: 約165行以下に圧縮）
- 指示品質の例を最小限に統合

### 8. templates/apply-improvements.md（修正）
**対応フィードバック**: I-7: テンプレート apply-improvements.md の返答行数制約未定義

**変更内容**:
- 行29-38: 返答フォーマットセクション → 「modified リストは最大20件まで（超過分は `... and {N} more` で省略）、skipped リストは最大10件まで（超過分は `... and {N} more` で省略）」という制約を追加

## 新規作成ファイル
（なし）

## 削除推奨ファイル
（なし）

## 実装順序
1. **SKILL.md（変更1）**: 外部参照削除、目的明確化、エラーハンドリング強化、検証ロジック追加 — 他の変更の前提となるワークフロー定義の修正
2. **templates/apply-improvements.md（変更8）**: 返答行数制約追加 — SKILL.md Phase 2 Step 4 で参照されるため、次に実施
3. **agents/ 配下の全ファイル（変更2-7）**: 検出戦略セクションの圧縮 — 並列実施可能（相互依存なし）

依存関係の理由:
- SKILL.md の変更（特に Phase 2 Step 4 の検証ロジック強化）が apply-improvements.md の返答フォーマット要件に影響する
- apply-improvements.md の返答行数制約は SKILL.md から参照されるため、SKILL.md 変更後に実施
- agents/ 配下のファイルは独立しており、SKILL.md の Phase 1 で並列起動されるため、相互依存なし

## 注意事項
- SKILL.md の変更はワークフロー全体に影響するため、特に Phase 1 のエラーハンドリング（I-1）と Phase 2 の検証ステップ（I-4, I-5, I-9）の変更で既存のロジックが壊れないよう慎重に実施すること
- バックアップ失敗時の処理追加（C-3）により Phase 2 Step 4 の制御フローが変更されるため、検証ステップとの整合性を確保すること
- 最終確認の AskUserQuestion 追加（C-4）により Phase 2 Step 4 の開始位置が変わるため、SKILL.md の行番号参照に注意すること
- agents/ 配下のファイル圧縮（I-6）は、検出戦略の説明を削減するが、検出品質を維持すること（具体例の削減のみ、検出ロジック自体は削除しない）
- apply-improvements.md の返答行数制約追加（I-7）は、SKILL.md Phase 2 Step 4 の検証ステップで `modified: 0件` を検出するロジック（I-5）と連携するため、フォーマット整合性を保つこと
