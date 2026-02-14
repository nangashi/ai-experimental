## 重大な問題

### C-1: 親からの共通フレームワーク要約展開が冗長 [efficiency]
- 対象: SKILL.md Phase 1 L142-146
- 内容: 各次元エージェントファイルに既に「共通フレームワーク」セクションが存在し同内容を記載しているため、親から analysis-framework.md を読み込んで要約を展開する処理は冗長。サブエージェントは次元エージェントファイルを Read すれば共通フレームワークを取得できる
- 推奨: Phase 1 の共通フレームワーク要約抽出・展開処理（L142-146 および Task prompt 内の展開指示）を削除し、各次元エージェントが自身のファイル内の共通フレームワークセクションを参照する方式に変更する
- impact: high, effort: low

### C-2: audit-approved.md 上書き時の重複データ問題 [stability]
- 対象: SKILL.md Phase 2 Step 3 L240
- 内容: Write で audit-approved.md を上書きすると、同じスキル実行の2回目以降で前回の承認結果が失われる。run-YYYYMMDD-HHMMSS サブディレクトリは冪等性確保されているが、audit-approved.md は常に上書きされるため履歴追跡が不可能。Phase 3 の前回比較（L327-332）には過去の findings ID が必要なため、上書きにより情報欠落が発生
- 推奨: audit-approved.md を {run_dir}/ 配下に保存し、最新版へのシンボリックリンクを .agent_audit/{agent_name}/audit-approved.md に作成する。または上書き前に Read した内容を {previous_approved_findings} 変数に保持してコンテキストで管理する方式に変更
- impact: high, effort: medium

### C-3: グループ分類サブエージェント返答の抽出失敗時の具体的エラー内容が不明 [stability]
- 対象: SKILL.md Phase 0 L88-91
- 内容: 抽出失敗時の条件は列挙されているが、「形式不一致、不正な値、複数行存在」のどれが発生したかをユーザーに報告する処理が欠落。失敗理由が分からないとデバッグが困難
- 推奨: L91 の警告表示を「⚠ グループ分類結果の抽出に失敗しました（{理由: 形式不一致/不正な値/複数行存在}）。デフォルト値 "unclassified" を使用します。」に変更し、失敗理由を含める処理を追加
- impact: medium, effort: low

### C-4: dim_summaries から件数取得の記述矛盾 [stability]
- 対象: SKILL.md Phase 2 Step 1 L201
- 内容: dim_summaries から件数を取得と記載があるが、analysis.md によると実際は抽出結果から集計となっており、定義が矛盾。resolved-issues.md の Phase 2 Step 1 件数集計で「dim_summaries から直接件数を取得」と記載されているが、SKILL.md L201 では「抽出結果から集計」と矛盾
- 推奨: Phase 2 Step 1 の L201「抽出した findings を severity 順（critical → improvement）にソートする」の後に「`{total}` = `{dim_summaries}` から全次元の critical + improvement 件数を合計」を追加し、dim_summaries の使用を明示する
- impact: medium, effort: low

## 改善提案

### I-1: Phase 3 前回比較の情報源が不明確 [effectiveness]
- 対象: SKILL.md Phase 3 L327-332
- 内容: 「前回承認済みで今回検出されなかった finding ID」「今回承認済みで前回存在しなかった finding ID」を表示するとあるが、前回の findings ファイル（run-*/audit-*.md）が保持されているか、audit-approved.md のみから復元するかが不明。audit-approved.md には finding ID が記載されているが、次元別ファイルの保存期間が定義されていない
- 推奨: 前回の findings を正確に比較するためには、少なくとも最新1世代の run-*/ を保持するか、audit-approved.md に次元情報を含めるかの設計を明示すべき
- impact: medium, effort: medium

### I-2: グループ分類失敗時のデフォルト値の妥当性 [effectiveness]
- 対象: SKILL.md Phase 0 Step 4
- 内容: グループ抽出失敗時は "unclassified" をデフォルト値として使用するが、unclassified の次元セット（IC, SA軽量版, WC）が全てのエージェントタイプに対して適切かが推定できない。特に evaluator 専用の次元（CE, DC）や producer 専用の次元（OF）を持つエージェントが unclassified と誤分類された場合、重要な問題が検出されない可能性がある
- 推奨: 分類失敗時のフォールバック戦略（再分類、全次元分析、ユーザー確認等）を検討すると有効性が向上する
- impact: medium, effort: medium

### I-3: Phase 1 並列分析の部分失敗時の続行条件が明示されていない [architecture]
- 対象: SKILL.md Phase 1
- 内容: 全次元が失敗した場合の処理は定義されているが、部分失敗時（例: 5次元中2次元成功）の続行条件が明示されていない。「成功した次元のみを Phase 2 で処理」と記述されているが、最小成功数（N次元中M成功で続行等）の閾値が設計意図として必要かが不明確
- 推奨: 現状は1次元でも成功すれば続行と推測されるが、明示が望ましい
- impact: medium, effort: low

### I-4: audit-approved.md の構造検証範囲 [architecture]
- 対象: SKILL.md Phase 2 検証ステップ
- 内容: `audit-approved.md` の構造検証が定義されていない。最終成果物として `.agent_audit/{agent_name}/audit-approved.md` を生成するが、必須セクション（重大な問題、改善提案）や必須フィールド（内容、根拠、推奨）の存在確認がない。agent_path の検証は行われているが、approved findings ファイルの品質保証が不足している
- 推奨: audit-approved.md に対する構造検証（必須セクション・フィールドの存在確認）を追加する
- impact: medium, effort: medium

### I-5: Phase 1 findings ファイルの「空」判定基準が不明 [stability]
- 対象: SKILL.md Phase 1 L169
- 内容: 「空でない」の定義が曖昧（0バイト/空行のみ/Summary セクションなし等）
- 推奨: 「ファイルサイズが0バイトでない」または「Summary セクションが存在する」等の具体的基準を明示
- impact: medium, effort: low

### I-6: ファイルスコープの参照パターン [architecture]
- 対象: SKILL.md Phase 0, Phase 1
- 内容: 絶対パス表記（`.claude/skills/agent_audit_new/...`）が使用されているが、スキルディレクトリ移動時に全パスの修正が必要になる
- 推奨: パス変数 `{skill_path}` を導入し、`{skill_path}/group-classification.md` のように相対パス化すると、スキルの移植性が向上する
- impact: medium, effort: medium

### I-7: Phase 1 テンプレート外部化の不徹底 [architecture]
- 対象: SKILL.md Phase 1
- 内容: 各次元分析のプロンプトが12行のインライン記述になっている（`.claude/skills/agent_audit_new/agents/{dim_path}.md` を Read し...～共通フレームワーク要約展開まで）
- 推奨: テンプレート参照パターンに完全移行すると、共通フレームワーク要約の渡し方がパス変数化され、可読性が向上する
- impact: medium, effort: medium

### I-8: Phase 3 前回比較における「解決済み指摘」の導出方法が未定義 [stability]
- 対象: SKILL.md Phase 3 L331
- 内容: 「前回承認済みで今回検出されなかった finding ID」の比較方法（ID文字列照合/タイトル類似度/内容一致等）が明示されていない
- 推奨: 前回と今回の finding ID セットの差分を取る処理を明示する（例: 「前回 audit-approved.md の全 finding ID を抽出し、今回の全検出 finding ID（Phase 1 全次元）と照合」）
- impact: medium, effort: low

### I-9: Phase 2 検証ステップにおける「必須セクション欠落」時の処理が不明確 [stability]
- 対象: SKILL.md L289-292
- 内容: グループ別必須セクション検証で欠落検出後、どのセクション欠落がロールバック対象かの判定基準がない
- 推奨: 全必須セクションが存在する場合のみ検証成功とするか、部分的欠落を許容するかを明示（例: 「いずれか1つでも欠落した場合は検証失敗」）
- impact: medium, effort: low

---
注: 改善提案を 5 件省略しました（合計 14 件中上位 9 件を表示）。省略された項目は次回実行で検出されます。
