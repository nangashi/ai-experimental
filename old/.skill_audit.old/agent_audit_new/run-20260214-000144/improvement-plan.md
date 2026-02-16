# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | 外部スキルパス参照を修正、group-classification.md埋め込み、frontmatter不在時確認追加、Phase 1エラーハンドリング簡素化、Phase 2エラーハンドリング追加、Phase 3出力修正、検証失敗時確認追加 | C-1, C-3, C-4, C-6, I-1, I-3, I-5, I-6, I-7, I-8, I-9 |
| 2 | templates/apply-improvements.md | 修正 | 返答フォーマット拡張（finding ID 単位の適用状態マッピング追加） | C-2, I-2, I-4 |

## 削除推奨ファイル
| ファイル | 理由 | 対応フィードバック |
|---------|------|------------------|
| agent_bench/ ディレクトリ全体 | 別スキルの全ファイルが含まれており、スキル境界が曖昧。外部スキルとして分離すべき | C-5 |
| group-classification.md | SKILL.md に埋め込むことでコンテキスト削減と一貫性確保 | I-8 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**:
- C-1: 外部スキルパスへの参照
- C-3: 条件分岐の欠落: Phase 2 改善適用失敗時のelse節
- C-4: 冪等性: Phase 1再実行時のfindingsファイル重複
- C-6: 参照整合性: Phase 1サブエージェント返答フォーマットの不一致
- I-1: エッジケース処理適正化: AskUserQuestionフォールバック不足
- I-3: Phase 2 Step 1の冗長Read
- I-5: 条件分岐の適正化: Phase 1サブエージェント失敗判定の過剰分岐
- I-6: Phase 1エラーハンドリングの二重Read
- I-7: 目的の明確性: 成功基準の明確化
- I-8: 指示の具体性: Phase 0 グループ分類の判定基準参照の曖昧性
- I-9: 条件分岐の欠落: Phase 0 frontmatter不在時の動作方針

**変更内容**:

1. **line 4-10（目的セクション）**: 成功基準を追加
   - 現在: 「エージェント定義ファイルのコンテンツ（評価基準、スコープ、指示の品質）を静的に分析し、構造最適化（agent_bench）では解決できない内容レベルの問題を特定・改善します。」
   - 改善後: 同文に続けて「**成功基準**: critical/improvement findings の検出→ユーザー承認→改善適用→検証成功により、エージェント定義の品質問題が解消されること」を追加

2. **line 58**: frontmatter不在時の処理を変更
   - 現在: 「存在しない場合、「⚠ このファイルにはエージェント定義の frontmatter がありません。エージェント定義ではない可能性があります。」とテキスト出力する（処理は継続する）」
   - 改善後: 「存在しない場合、AskUserQuestion で「⚠ このファイルにはエージェント定義の frontmatter がありません。エージェント定義ではない可能性があります。続行しますか？」と確認する。「いいえ」の場合は終了する」

3. **line 28-37（グループ定義セクション）の後に group-classification.md の内容を埋め込み**:
   - group-classification.md の「evaluator 特徴（4項目）」「producer 特徴（4項目）」「判定ルール」のセクションを SKILL.md の line 37 の後に挿入する
   - 新セクション見出し: `### 分類基準の詳細`

4. **line 64-72（グループ分類の判定ルール）**: 外部参照を削除し埋め込みセクションへの参照に変更
   - 現在: 「分類基準の詳細は `.claude/skills/agent_audit/group-classification.md` を参照。判定ルール（概要）: ...」
   - 改善後: 「判定ルール: 上記「分類基準の詳細」に従い、以下の順序で評価する: ...」（概要を削除し、詳細セクションへの参照のみ残す）

5. **line 81の後に Phase 0 Step 7a を追加**: Phase 1再実行時の冪等性確保
   - 挿入内容: 「7a. 既存の findings ファイルを削除する: `rm -f .agent_audit/{agent_name}/audit-*.md` を Bash で実行する（Phase 1の再実行時に重複を防ぐ）」

6. **line 115**: 外部スキルパス参照を修正
   - 現在: `.claude/skills/agent_audit/agents/{dim_path}.md`
   - 改善後: `.claude/skills/agent_audit_new/agents/{dim_path}.md`

7. **line 125-129（Phase 1エラーハンドリング）**: 成否判定を簡素化
   - 現在: 「対応する findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）が存在し、空でない → 成功。件数はファイル内の `## Summary` セクションから抽出する（抽出失敗時は findings ファイル内の `### {ID_PREFIX}-` ブロック数から推定する）」
   - 改善後: 「対応する findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）が存在する → 成功」

8. **line 148**: Phase 2 Step 1の冗長Read削除
   - 現在: 「Phase 1 で成功した全次元の findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）を Read する。各ファイルから severity が critical または improvement の finding（`###` ブロック単位）を抽出し、critical → improvement の順にソートする。」
   - 改善後: 「Phase 1 で成功した全次元の findings ファイルパスのリストを作成する（Read は実行しない）。」

9. **line 189の後（Step 3の承認結果保存後）に approved.md の構造指示を追加**:
   - 挿入内容: 「保存時は findings ファイルから該当 finding のみを抽出し、ユーザー判定と修正内容を追記する。findings の全内容を親コンテキストで保持しない（ファイル直接参照を使用）」

10. **line 221**: 外部スキルパス参照を修正
    - 現在: `.claude/skills/agent_audit/templates/apply-improvements.md`
    - 改善後: `.claude/skills/agent_audit_new/templates/apply-improvements.md`

11. **line 226の後に Phase 2 Step 4のエラーハンドリングを追加**:
    - 挿入内容: 「**エラーハンドリング**: サブエージェント実行失敗時（返答が取得できない、または findings ファイルパスの指定が不正等）は、「改善適用に失敗しました: {エラー概要}」とテキスト出力し、AskUserQuestion で「再試行/Phase 3へスキップ/キャンセル」を確認する。キャンセル選択時は終了する」

12. **line 235の検証失敗時の処理にAskUserQuestion追加**:
    - 現在: 「検証失敗時: 「✗ 検証失敗: エージェント定義が破損している可能性があります。以下のコマンドでロールバックできます: `cp {backup_path} {agent_path}`」とテキスト出力し、Phase 3 でも警告を表示」
    - 改善後: 「検証失敗時: 「✗ 検証失敗: エージェント定義が破損している可能性があります。」とテキスト出力し、AskUserQuestion で「ロールバックしますか？（`cp {backup_path} {agent_path}` を実行）」を確認する。「はい」選択時は Bash でロールバック実行後、Phase 3 で警告を表示して終了。「いいえ」選択時は Phase 3 で警告のみ表示」

13. **line 263-266（Phase 3変更詳細出力）**: 出力内容を修正
    - 現在: 「変更詳細: 適用成功: {N}件（{finding ID リスト}）, 適用スキップ: {K}件（{finding ID: スキップ理由}）」
    - 改善後: 「変更詳細: {apply-improvements サブエージェントの返答内容をそのまま表示（modified, skipped リスト）}」

### 2. templates/apply-improvements.md（修正）
**対応フィードバック**:
- C-2: データフロー妥当性: Phase 3で参照する変更詳細が収集されていない
- I-2: データフロー妥当性: Phase 2 Step 4返答の親コンテキスト保持
- I-4: 出力フォーマット決定性: Phase 2 Step 4サブエージェント返答フォーマットの曖昧性

**変更内容**:

1. **line 29-38（返答フォーマット）**: finding ID 単位の適用状態マッピングを追加
   - 現在:
     ```
     modified: {N}件
       - {finding ID} → {ファイルパス}:{セクション名}: {変更概要}
     skipped: {K}件
       - {finding ID}: {スキップ理由}
     ```
   - 改善後:
     ```
     modified: {N}件
       - {finding ID} → {ファイルパス}:{セクション名}: {変更概要}
     skipped: {K}件
       - {finding ID}: {スキップ理由}

     （改善計画の全 finding に対して適用状態を記録）
     ```

2. **line 1の前に目的説明を追加**:
   - 挿入内容: 「# 改善適用テンプレート\n\n承認済み監査 findings に基づいてエージェント定義を改善し、各 finding の適用状態（modified/skipped）を返答します。\n」

## 実装順序

1. **SKILL.md の変更**（最優先）
   - 理由: C-1（外部スキルパス参照）は即座に実行時エラーを引き起こす critical 指摘。他の全変更の前提となる
   - 依存: なし

2. **templates/apply-improvements.md の変更**
   - 理由: SKILL.md の Phase 2/3 が apply-improvements の返答フォーマットに依存する
   - 依存: なし（SKILL.md と独立に変更可能だが、SKILL.md 修正後に返答フォーマットが整合）

3. **agent_bench/ ディレクトリの削除（手動対応を推奨）**
   - 理由: 別スキルの全体が含まれており、削除はスキル構造の大幅な変更。手動確認が必要
   - 依存: なし

4. **group-classification.md の削除**
   - 理由: SKILL.md への埋め込み完了後に削除可能
   - 依存: SKILL.md の変更（line 28-37後の埋め込み）完了後

## 注意事項

- **C-1の即時対応**: 外部スキルパス参照は実行時エラーの原因となるため、最優先で修正する
- **C-5の手動対応**: agent_bench/ ディレクトリの削除は別スキルの構造に影響するため、本改善計画では削除推奨のみ記載し、実際の削除は手動確認後に実施する
- **group-classification.md の削除タイミング**: SKILL.md への埋め込み完了後、外部参照が完全に削除されたことを確認してから削除する
- **Phase 1/2 のサブエージェント起動**: line 115, 221 のパス修正により、全サブエージェント委譲が正常動作することを確認する
- **Phase 3 の出力整合性**: apply-improvements の返答フォーマット変更により、Phase 3 の変更詳細表示が正確になることを確認する
- **検証ステップの強化**: frontmatter 不在時確認、検証失敗時のロールバック確認により、エラー時の安全性が向上する
