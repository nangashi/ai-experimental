# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 0 グループ分類の直接実装化、Phase 1 テンプレート削除対応、Phase 1/3 エラーハンドリング強化、Phase 2 承認ロジック改善 | I-4, I-7, C-1, I-1, I-2, I-5, I-6, C-2, I-8, I-9 |
| 2 | agents/evaluator/criteria-effectiveness.md | 修正 | プレースホルダー削除、analysis-framework.md 直接読込指示追加 | I-3 |
| 3 | agents/evaluator/scope-alignment.md | 修正 | プレースホルダー削除、analysis-framework.md 直接読込指示追加 | I-3 |
| 4 | agents/evaluator/detection-coverage.md | 修正 | プレースホルダー削除、analysis-framework.md 直接読込指示追加 | I-3 |
| 5 | agents/producer/workflow-completeness.md | 修正 | プレースホルダー削除、analysis-framework.md 直接読込指示追加 | I-3 |
| 6 | agents/producer/output-format.md | 修正 | プレースホルダー削除、analysis-framework.md 直接読込指示追加 | I-3 |
| 7 | agents/shared/instruction-clarity.md | 修正 | プレースホルダー削除、analysis-framework.md 直接読込指示追加 | I-3 |
| 8 | agents/unclassified/scope-alignment.md | 修正 | プレースホルダー削除、analysis-framework.md 直接読込指示追加 | I-3 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**:
- I-4: Phase 0 グループ分類サブエージェントは直接実装可能
- I-7: Phase 1 analyze-dimensions.md テンプレートは冗長
- C-1: findings ファイルの Summary セクション形式が未定義
- I-1: Phase 1 findings ファイル読込時の2次抽出失敗処理が不明確
- I-2: Phase 2 Step 1 severity フィールドのバリデーションが不足
- I-5: Phase 2 Step 2a の「残りすべて承認」選択肢を分割
- I-6: Phase 0 グループ分類抽出失敗時の理由表現を明確化
- C-2: 前回承認済み findings からの ID 抽出方法が未定義
- I-8: Phase 3 前回比較のID抽出失敗時の処理を明示
- I-9: Phase 3 前回比較サマリの形式を明示

**変更内容**:
- **Phase 0 Step 4（グループ分類）**: haiku サブエージェント委譲を削除し、親エージェントが直接分類を実施する。group-classification.md の4項目分類基準を SKILL.md 内に統合し、Read → 判定ロジック実装に変更
- **Phase 0 Step 4 エラーハンドリング（lines 90-93）**: `抽出失敗時（形式不一致、不正な値、複数行存在）は、{agent_group} = "unclassified"` → 以下に変更:
  ```
  判定失敗時は {agent_group} = "unclassified" をデフォルト値として使用し、警告を表示:
  - 形式不一致: 返答に `group: {value}` 行が存在しない
  - 不正な値: `{value}` が hybrid/evaluator/producer/unclassified のいずれでもない
  - 複数行存在: `group:` 行が2つ以上存在する
  警告テキスト: 「⚠ グループ分類が失敗しました（理由: {具体的な理由}、ファイル先頭100文字: {agent_path 内容の最初の100文字}）。デフォルト値 "unclassified" を使用します。」
  ```
- **Phase 1 Task prompt（lines 145-155）**: `templates/analyze-dimensions.md` への参照を削除し、直接次元エージェントに委譲する形式に変更:
  ```
  > `{dim_agent_path}` を Read し、その指示に従って分析を実行してください。
  >
  > パス変数:
  > - `{agent_path}`: {実際の agent_path の絶対パス}
  > - `{agent_name}`: {実際の agent_name}
  > - `{previous_approved_path}`: {実際の previous_approved_path}
  > - `{findings_save_path}`: {実際の .agent_audit/{agent_name}/run-YYYYMMDD-HHMMSS/audit-{ID_PREFIX}.md の絶対パス}
  >
  > 分析完了後、以下のフォーマットで返答してください（4行固定）:
  > ```
  > dim: {次元名}
  > critical: {N}
  > improvement: {M}
  > info: {K}
  > ```
  ```
- **Phase 1 エラーハンドリング（lines 161-163）**: `抽出失敗時は findings ファイルを Read し、\`## Summary\` セクション内の件数を抽出する` → 以下に変更:
  ```
  抽出失敗時は findings ファイルを Read し、`## Summary` セクション内の件数を抽出する。Summary セクションの形式:
  ```
  ## Summary
  - Total findings: {N}
    - Critical: {N_critical}
    - Improvement: {N_improvement}
    - Info: {N_info}
  ```
  Summary セクションが存在しない、または形式が異なる場合、該当次元は「分析失敗（Summary セクション不在またはフォーマット不正）」として記録する
  ```
- **Phase 2 Step 1（lines 183-193）**: severity フィールド抽出後に以下のバリデーションを追加:
  ```
  5. severity フィールドのバリデーション:
     - フィールド欠落時: 該当 finding をスキップし、警告表示「⚠ {ファイル名} の {ID} は severity フィールドが欠落しているためスキップしました。」
     - 不正値（critical/improvement/info 以外）: 該当 finding をスキップし、警告表示「⚠ {ファイル名} の {ID} は認識できない severity 値 "{値}" のためスキップしました。」
  6. severity が `critical` または `improvement` の finding のみを対象とする（変更なし）
  ```
- **Phase 2 Step 2a（line 228）**: `「残りすべて承認」: この指摘を含め、未確認の全指摘（critical と improvement の両方）を severity に関係なく承認としてループを終了する` → 以下に変更:
  ```
  「残りすべて承認」: AskUserQuestion で確認ダイアログを表示「残り {未確認件数} 件（critical {N}, improvement {M}）を severity に関係なく全て承認します。よろしいですか？」選択肢: "Yes"（承認して終了）、"No"（現在の指摘に戻る）。Yes 選択時、この指摘を含め未確認の全指摘を承認としてループを終了する
  ```
- **Phase 3 前回比較（lines 330-333）**: ID 抽出方法と失敗時処理を明示:
  ```
  - 解決済み指摘の導出:
    1. {previous_approved_path} を Read し、正規表現 `^### ([A-Z]{2}-\d+):` で各行から finding ID を抽出（{previous_ids}）
    2. 今回承認済み findings（audit-approved.md）を Read し、同様に finding ID を抽出（{current_ids}）
    3. {previous_ids} - {current_ids} の差分を「解決済み指摘」とする
    4. ID 抽出失敗時（正規表現にマッチする行が0件）: 該当ファイルの ID セットを空とみなし、警告表示「⚠ {ファイル名} から finding ID を抽出できませんでした。」
  - 新規指摘の導出: {current_ids} - {previous_ids} の差分を「新規指摘」とする
  - 解決済み指摘: {カンマ区切り ID リスト（なければ「なし」）}
  - 新規指摘: {カンマ区切り ID リスト（なければ「なし」）}
  ```

### 2. agents/evaluator/criteria-effectiveness.md（修正）
**対応フィードバック**: I-3: 共通フレームワーク要約展開の残骸プレースホルダを削除

**変更内容**:
- **## 共通フレームワーク セクション（lines 6-12）**: 現在の記述 →
  ```
  ## 共通フレームワーク

  全次元共通の分析フレームワークは `{skill_path}/agents/shared/analysis-framework.md` に定義されています。
  分析開始前に Read で読み込み、Phase 1（包括的検出）と Phase 2（整理・報告）の手順に従ってください。

  以下は Criteria Effectiveness 固有の検出ロジックです。
  ```

### 3. agents/evaluator/scope-alignment.md（修正）
**対応フィードバック**: I-3: 共通フレームワーク要約展開の残骸プレースホルダを削除

**変更内容**:
- **## 共通フレームワーク セクション**: 現在の記述 →
  ```
  ## 共通フレームワーク

  全次元共通の分析フレームワークは `{skill_path}/agents/shared/analysis-framework.md` に定義されています。
  分析開始前に Read で読み込み、Phase 1（包括的検出）と Phase 2（整理・報告）の手順に従ってください。

  以下は Scope Alignment (Evaluator) 固有の検出ロジックです。
  ```

### 4. agents/evaluator/detection-coverage.md（修正）
**対応フィードバック**: I-3: 共通フレームワーク要約展開の残骸プレースホルダを削除

**変更内容**:
- **## 共通フレームワーク セクション**: 現在の記述 →
  ```
  ## 共通フレームワーク

  全次元共通の分析フレームワークは `{skill_path}/agents/shared/analysis-framework.md` に定義されています。
  分析開始前に Read で読み込み、Phase 1（包括的検出）と Phase 2（整理・報告）の手順に従ってください。

  以下は Detection Coverage 固有の検出ロジックです。
  ```

### 5. agents/producer/workflow-completeness.md（修正）
**対応フィードバック**: I-3: 共通フレームワーク要約展開の残骸プレースホルダを削除

**変更内容**:
- **## 共通フレームワーク セクション**: 現在の記述 →
  ```
  ## 共通フレームワーク

  全次元共通の分析フレームワークは `{skill_path}/agents/shared/analysis-framework.md` に定義されています。
  分析開始前に Read で読み込み、Phase 1（包括的検出）と Phase 2（整理・報告）の手順に従ってください。

  以下は Workflow Completeness 固有の検出ロジックです。
  ```

### 6. agents/producer/output-format.md（修正）
**対応フィードバック**: I-3: 共通フレームワーク要約展開の残骸プレースホルダを削除

**変更内容**:
- **## 共通フレームワーク セクション**: 現在の記述 →
  ```
  ## 共通フレームワーク

  全次元共通の分析フレームワークは `{skill_path}/agents/shared/analysis-framework.md` に定義されています。
  分析開始前に Read で読み込み、Phase 1（包括的検出）と Phase 2（整理・報告）の手順に従ってください。

  以下は Output Format 固有の検出ロジックです。
  ```

### 7. agents/shared/instruction-clarity.md（修正）
**対応フィードバック**: I-3: 共通フレームワーク要約展開の残骸プレースホルダを削除

**変更内容**:
- **## 共通フレームワーク セクション**: 現在の記述 →
  ```
  ## 共通フレームワーク

  全次元共通の分析フレームワークは `{skill_path}/agents/shared/analysis-framework.md` に定義されています。
  分析開始前に Read で読み込み、Phase 1（包括的検出）と Phase 2（整理・報告）の手順に従ってください。

  以下は Instruction Clarity 固有の検出ロジックです。
  ```

### 8. agents/unclassified/scope-alignment.md（修正）
**対応フィードバック**: I-3: 共通フレームワーク要約展開の残骸プレースホルダを削除

**変更内容**:
- **## 共通フレームワーク セクション**: 現在の記述 →
  ```
  ## 共通フレームワーク

  全次元共通の分析フレームワークは `{skill_path}/agents/shared/analysis-framework.md` に定義されています。
  分析開始前に Read で読み込み、Phase 1（包括的検出）と Phase 2（整理・報告）の手順に従ってください。

  以下は Scope Alignment (Unclassified) 固有の検出ロジックです。
  ```

## 新規作成ファイル
（なし）

## 削除推奨ファイル
| ファイル | 理由 | 対応フィードバック |
|---------|------|------------------|
| templates/analyze-dimensions.md | テンプレートが実質パス変数展開のみで冗長。親エージェントが直接次元エージェントに委譲する形式に変更 | I-7 |

## 実装順序
1. **agents/ 配下の全次元エージェントファイル（2-8）**: プレースホルダー削除と analysis-framework.md 直接読込指示への変更。これらは互いに独立しており、SKILL.md の変更前に完了できる
2. **SKILL.md**: Phase 0 グループ分類の直接実装化、Phase 1 テンプレート削除対応、Phase 1/2/3 エラーハンドリング強化。次元エージェントファイルの変更完了後に実施（analyze-dimensions.md テンプレート削除対応のため）
3. **templates/analyze-dimensions.md の削除**: SKILL.md の Phase 1 変更完了後に削除

依存関係の検出方法:
- agents/ 配下ファイルの変更（プレースホルダー削除）は互いに独立しており並列実施可能
- SKILL.md は Phase 1 で analyze-dimensions.md を参照しなくなるため、エージェントファイル変更完了後に実施
- analyze-dimensions.md 削除は SKILL.md の変更完了を確認してから実施

## 注意事項
- **Phase 0 グループ分類の直接実装化（I-4）**: group-classification.md の4項目分類基準（evaluator/producer 特徴）を SKILL.md Phase 0 Step 4 に統合する。group-classification.md ファイル自体は削除せず保持（将来の参照用）
- **Phase 1 テンプレート削除（I-7）**: analyze-dimensions.md テンプレート削除後、SKILL.md の Task prompt が直接次元エージェントファイルを参照することを確認する。次元エージェントファイルの返答フォーマット（4行固定）は変更なし
- **Summary セクション形式定義（C-1）**: findings ファイルに含まれるべき Summary セクション形式を SKILL.md Phase 1 エラーハンドリングに明示する。次元エージェントファイルには Summary セクション生成指示が既に含まれているため、変更不要
- **前回比較のID抽出方法（C-2, I-8）**: 正規表現 `^### ([A-Z]{2}-\d+):` を使用。抽出失敗時は該当ファイルの ID セットを空とみなし警告表示
- **変更によって既存のワークフローが壊れないこと**: 全ての変更は内部実装の改善であり、スキルのインターフェース（`/agent_audit <file_path>`）と出力形式（.agent_audit/ ディレクトリ構造）は変更なし
