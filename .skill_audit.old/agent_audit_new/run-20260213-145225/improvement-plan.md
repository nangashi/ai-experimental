# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 1 共通フレームワーク要約処理の削除 | C-1 |
| 2 | SKILL.md | 修正 | audit-approved.md を run_dir 配下に保存しシンボリックリンク作成 | C-2, I-1 |
| 3 | SKILL.md | 修正 | グループ分類失敗時のエラー内容明示 | C-3 |
| 4 | SKILL.md | 修正 | dim_summaries からの件数取得を明示 | C-4 |
| 5 | SKILL.md | 修正 | グループ分類失敗時のフォールバック戦略を文書化 | I-2 |
| 6 | SKILL.md | 修正 | Phase 1 部分失敗時の続行条件を明示 | I-3 |
| 7 | SKILL.md | 修正 | Phase 2 audit-approved.md 構造検証を追加 | I-4 |
| 8 | SKILL.md | 修正 | Phase 1 findings ファイル「空」判定基準を明示 | I-5 |
| 9 | SKILL.md | 修正 | {skill_path} パス変数導入と相対パス化 | I-6 |
| 10 | templates/analyze-dimensions.md | 新規作成 | Phase 1 次元分析プロンプトをテンプレート化 | I-7 |
| 11 | SKILL.md | 修正 | Phase 1 テンプレート参照パターンへ移行 | I-7 |
| 12 | SKILL.md | 修正 | Phase 3 finding ID セット差分処理を明示 | I-8 |
| 13 | SKILL.md | 修正 | Phase 2 検証ステップの必須セクション欠落判定を明示 | I-9 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**: C-1: 親からの共通フレームワーク要約展開が冗長

**変更内容**:
- Phase 1 L140-146（共通フレームワーク要約の準備セクション）: 削除
- Phase 1 L151-161（Task prompt）: 「共通フレームワーク要約:」部分を削除
- Phase 1 各次元エージェント指示: 各次元エージェントが自身のファイル内「## 共通フレームワーク」セクションを参照する方式に変更（次元エージェントファイル側は既にセクション存在のため変更不要）

---

### 2. SKILL.md（修正）
**対応フィードバック**: C-2: audit-approved.md 上書き時の重複データ問題, I-1: Phase 3 前回比較の情報源が不明確

**変更内容**:
- L36-37（パス変数）: `{approved_findings_path}` を `.agent_audit/{agent_name}/run-{timestamp}/audit-approved.md` に変更
- L104-105（出力ディレクトリ作成の注記）: 削除（audit-approved.md も run_dir 配下に保存）
- Phase 0 L106-110（前回実行履歴の確認）:
  - 現在: `.agent_audit/{agent_name}/audit-approved.md` を Read → 変更後: Bash で `readlink .agent_audit/{agent_name}/audit-approved.md` を実行し、シンボリックリンクが存在する場合はリンク先を Read、存在しない場合は `{previous_approved_count} = 0`
  - `{previous_approved_path}` = シンボリックリンク先のパス（存在する場合）
- Phase 2 Step 3 L240: `Write` で `.agent_audit/{agent_name}/run-{timestamp}/audit-approved.md` に保存後、Bash で `ln -sf run-{timestamp}/audit-approved.md .agent_audit/{agent_name}/audit-approved.md` を実行してシンボリックリンクを作成
- Phase 3 L327-332（前回比較）: 前回の findings ファイル（`{previous_approved_path}`）を Read し、finding ID セットを抽出して比較

---

### 3. SKILL.md（修正）
**対応フィードバック**: C-3: グループ分類サブエージェント返答の抽出失敗時の具体的エラー内容が不明

**変更内容**:
- Phase 0 L88-91（抽出失敗時のデフォルト値使用）:
  - 現在: `警告を表示: 「⚠ グループ分類結果の抽出に失敗しました。デフォルト値 "unclassified" を使用します。」`
  - 変更後: `警告を表示: 「⚠ グループ分類結果の抽出に失敗しました（理由: {形式不一致/不正な値/複数行存在}、返答内容: {サブエージェント返答の最初の100文字}）。デフォルト値 "unclassified" を使用します。」`

---

### 4. SKILL.md（修正）
**対応フィードバック**: C-4: dim_summaries から件数取得の記述矛盾

**変更内容**:
- Phase 1 L169（成功判定と件数抽出）:
  - 現在: `件数はサブエージェント返答から抽出し、{dim_summaries} に保存する。抽出失敗時は findings ファイルを Read し、## Summary セクション内の件数を抽出する`
  - 変更後: `サブエージェント返答から件数を抽出し、{dim_summaries} に保存する（形式: {次元名}: critical {N}, improvement {M}, info {K}）。抽出失敗時は findings ファイルを Read し、## Summary セクション内の件数を抽出する`
- Phase 2 Step 1 L201（件数集計）:
  - 現在: `{total} = 対象 finding の合計件数（critical と improvement の件数は抽出結果から集計）`
  - 変更後: `{total} = 対象 finding の合計件数（critical と improvement の件数は {dim_summaries} から集計。{dim_summaries} に記録されていない次元は抽出結果から集計）`

---

### 5. SKILL.md（修正）
**対応フィードバック**: I-2: グループ分類失敗時のデフォルト値の妥当性

**変更内容**:
- Phase 0 L88-91（デフォルト値使用）の警告表示に補足を追加:
  - 追加文: `注: unclassified グループは最小次元セット（IC/SA軽量版/WC）で分析します。より詳細な分析が必要な場合は、エージェント定義の frontmatter に evaluator/producer/hybrid の特徴を明示してください。`

---

### 6. SKILL.md（修正）
**対応フィードバック**: I-3: Phase 1 並列分析の部分失敗時の続行条件が明示されていない

**変更内容**:
- Phase 1 L172（全失敗時のエラー出力）の直前に追加:
  - 追加文: `1次元でも成功すれば Phase 2 へ進む。`

---

### 7. SKILL.md（修正）
**対応フィードバック**: I-4: audit-approved.md の構造検証範囲

**変更内容**:
- Phase 2 検証ステップ L282-295 に以下を追加（構造検証の項目3の前に挿入）:
  - `3. audit-approved.md 構造検証: Read で {approved_findings_path} を読み込み、以下を確認:`
    - `- "# 承認済み監査 Findings" ヘッダーの存在`
    - `- "承認: N/M件" 行の存在`
    - `- セクション "## 重大な問題" または "## 改善提案" のいずれか1つ以上の存在`
    - `- 各 finding の必須フィールド（ID, 内容, 根拠, 推奨, ユーザー判定）の存在`
  - 検証失敗時は Phase 3 へ直行（バックアップ保持）

---

### 8. SKILL.md（修正）
**対応フィードバック**: I-5: Phase 1 findings ファイルの「空」判定基準が不明

**変更内容**:
- Phase 1 L169（成功判定）:
  - 現在: `findings ファイルが存在しない、または空 → 失敗`
  - 変更後: `findings ファイルが存在しない、またはファイルサイズが10バイト未満（Bash で "test -s {findings_save_path} && [ $(stat -c%s {findings_save_path}) -ge 10 ]" が偽）→ 失敗`

---

### 9. SKILL.md（修正）
**対応フィードバック**: I-6: ファイルスコープの参照パターン

**変更内容**:
- L28-39（パス変数）の冒頭に追加: `{skill_path}`: `/home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_audit_new` の絶対パス（スキルディレクトリ）
- Phase 0 L84（group-classification.md 参照）:
  - 現在: `.claude/skills/agent_audit_new/group-classification.md`
  - 変更後: `{skill_path}/group-classification.md`
- Phase 1 L141（analysis-framework.md 参照）:
  - 現在: `.claude/skills/agent_audit_new/agents/shared/analysis-framework.md`
  - 変更後: `{skill_path}/agents/shared/analysis-framework.md`
- Phase 1 L152（各次元エージェントファイル参照）:
  - 現在: `.claude/skills/agent_audit_new/agents/{dim_path}.md`
  - 変更後: `{skill_path}/agents/{dim_path}.md`
- Phase 2 Step 4 L274（apply-improvements.md 参照）:
  - 現在: `.claude/skills/agent_audit_new/templates/apply-improvements.md`
  - 変更後: `{skill_path}/templates/apply-improvements.md`

---

### 10. templates/analyze-dimensions.md（新規作成）
**対応フィードバック**: I-7: Phase 1 テンプレート外部化の不徹底

**変更内容**: 新規作成
- Phase 1 の次元分析プロンプト（L152-161）を外部化
- 内容:
  ```markdown
  # 次元分析テンプレート

  `{dim_agent_path}` を Read し、その指示に従って分析を実行してください。

  ## パス変数
  - `{agent_path}`: {実際の agent_path の絶対パス}
  - `{agent_name}`: {実際の agent_name}
  - `{previous_approved_path}`: {実際の .agent_audit/{agent_name}/audit-approved.md へのシンボリックリンク先パス}（存在しない場合は空とみなす）
  - `{findings_save_path}`: {実際の .agent_audit/{agent_name}/run-YYYYMMDD-HHMMSS/audit-{ID_PREFIX}.md の絶対パス}
  - `{dim_agent_path}`: {実際の次元エージェントファイルの絶対パス}

  分析完了後、以下のフォーマットで返答してください（4行固定）:
  ```
  dim: {次元名}
  critical: {N}
  improvement: {M}
  info: {K}
  ```
  ```

---

### 11. SKILL.md（修正）
**対応フィードバック**: I-7: Phase 1 テンプレート外部化の不徹底

**変更内容**:
- L28-39（パス変数）に追加: `{dim_agent_path}`: 次元エージェントファイルの絶対パス（`{skill_path}/agents/{dim_path}.md`）
- Phase 1 L148-164（Task prompt）:
  - 現在: 12行のインライン記述
  - 変更後: `Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:
    ```
    > `{skill_path}/templates/analyze-dimensions.md` を Read し、その指示に従って分析を実行してください。
    >
    > パス変数:
    > - `{dim_agent_path}`: {実際の次元エージェントファイルの絶対パス}
    > - `{agent_path}`: {実際の agent_path の絶対パス}
    > - `{agent_name}`: {実際の agent_name}
    > - `{previous_approved_path}`: {実際の previous_approved_path}
    > - `{findings_save_path}`: {実際の .agent_audit/{agent_name}/run-YYYYMMDD-HHMMSS/audit-{ID_PREFIX}.md の絶対パス}
    ```

---

### 12. SKILL.md（修正）
**対応フィードバック**: I-8: Phase 3 前回比較における「解決済み指摘」の導出方法が未定義

**変更内容**:
- Phase 3 L327-332（前回比較）に以下を追加:
  - `- 解決済み指摘の導出: {previous_approved_path} を Read し、finding ID セットを抽出（{previous_ids}）。今回承認済み findings から finding ID セットを抽出（{current_ids}）。{previous_ids} - {current_ids} の差分を「解決済み指摘」とする`
  - `- 新規指摘の導出: {current_ids} - {previous_ids} の差分を「新規指摘」とする`

---

### 13. SKILL.md（修正）
**対応フィードバック**: I-9: Phase 2 検証ステップにおける「必須セクション欠落」時の処理が不明確

**変更内容**:
- Phase 2 検証ステップ L289-292（グループ別必須セクション検証）に以下を明示:
  - 現在: `- グループ別必須セクション検証:`
  - 変更後: `- グループ別必須セクション検証（いずれか1つでも欠落した場合は検証失敗）:`

## 新規作成ファイル
| ファイル | 目的 | 対応フィードバック |
|---------|------|------------------|
| templates/analyze-dimensions.md | Phase 1 次元分析プロンプトの外部化（テンプレート参照パターンへの完全移行） | I-7 |

## 削除推奨ファイル
なし

## 実装順序
1. **templates/analyze-dimensions.md の新規作成**（ファイル#10）— SKILL.md がこのテンプレートを参照するため先に作成
2. **SKILL.md の Phase 1 共通フレームワーク要約処理削除**（ファイル#1）— 独立した変更
3. **SKILL.md の {skill_path} パス変数導入**（ファイル#9）— ファイル#11（Phase 1 テンプレート参照）が {skill_path} を使用するため先に実施
4. **SKILL.md の Phase 1 テンプレート参照パターン移行**（ファイル#11）— ファイル#1, #9, #10 に依存
5. **SKILL.md の audit-approved.md 保存先変更**（ファイル#2）— Phase 2/3 全体に影響する変更のため早期実施
6. **SKILL.md の残りの修正**（ファイル#3-8, #12-13）— 相互依存なし、並列実施可能

依存関係の検出方法:
- ファイル#10（新規テンプレート）→ ファイル#11（テンプレート参照追加）の順
- ファイル#9（パス変数定義）→ ファイル#11（パス変数使用）の順

## 注意事項
- ファイル#2（audit-approved.md 保存先変更）は Phase 0, Phase 2, Phase 3 の複数箇所に影響するため、変更時に全箇所の整合性を確認すること
- ファイル#11（Phase 1 テンプレート参照）は既存の Task prompt（12行）を完全に置き換えるため、テンプレートファイル（ファイル#10）の内容が正確であることを確認すること
- Phase 2 検証ステップの変更（ファイル#7, #13）は検証失敗時の動作に影響するため、エラーハンドリングの整合性を確認すること
- {skill_path} パス変数（ファイル#9）はスキル移動時に変更が必要。スキルディレクトリの絶対パスをハードコードするか、スキル起動時に動的に取得する方式を検討すること
