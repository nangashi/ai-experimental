# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 1 のサブエージェントプロンプトを外部テンプレート化 | I-8 |
| 2 | templates/phase1-dimension-analysis.md | 新規作成 | Phase 1 用の分析次元テンプレート作成 | I-8 |
| 3 | SKILL.md | 修正 | Phase 1 返答フォーマット解析を削除しファイル存在確認のみに統一 | I-5, I-6 |
| 4 | SKILL.md | 修正 | ID_PREFIX → antipattern_catalog_path のマッピングテーブルを dim_path マッピングの直後に移動 | I-3 |
| 5 | SKILL.md | 修正 | Phase 0 Step 7a の削除対象ファイルパターンを明示的に列挙 | I-2 |
| 6 | SKILL.md | 修正 | Phase 2 Step 1-2 間に findings サマリヘッダ読み込みロジックを追加 | I-7 |
| 7 | agents/shared/instruction-clarity.md | 修正 | findings ファイルの先頭にサマリヘッダを追加 | I-7 |
| 8 | agents/evaluator/criteria-effectiveness.md | 修正 | findings ファイルの先頭にサマリヘッダを追加 | I-7 |
| 9 | agents/evaluator/scope-alignment.md | 修正 | findings ファイルの先頭にサマリヘッダを追加 | I-7 |
| 10 | agents/evaluator/detection-coverage.md | 修正 | findings ファイルの先頭にサマリヘッダを追加 | I-7 |
| 11 | agents/producer/workflow-completeness.md | 修正 | findings ファイルの先頭にサマリヘッダを追加 | I-7 |
| 12 | agents/producer/output-format.md | 修正 | findings ファイルの先頭にサマリヘッダを追加 | I-7 |
| 13 | agents/unclassified/scope-alignment.md | 修正 | findings ファイルの先頭にサマリヘッダを追加 | I-7 |
| 14 | SKILL.md | 修正 | Phase 2 Step 3-4 間に改善適用確認を追加 | I-1 |
| 15 | SKILL.md | 修正 | Phase 2 Step 3 に承認数0の場合の Phase 3 出力分岐を追加 | I-9 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）— Phase 1 プロンプト外部化
**対応フィードバック**: I-8: 長いインラインブロック（Phase 1）

**変更内容**:
- Line 148-158（サブエージェントプロンプトのインライン記述）: 以下の記述 → `.claude/skills/agent_audit_new/templates/phase1-dimension-analysis.md を Read し、その指示に従って分析を実行してください。` に置換
  - 現在の記述: 14行のインラインプロンプト
  - 改善後: 1行のテンプレート参照
- パス変数の受け渡し方法は変更なし（`{agent_path}`, `{agent_name}`, `{findings_save_path}`, `{antipattern_catalog_path}` を維持）

### 2. templates/phase1-dimension-analysis.md（新規作成）
**対応フィードバック**: I-8: 長いインラインブロック（Phase 1）

**変更内容**:
- 新規ファイル作成: SKILL.md Line 148-158 のインラインプロンプトを外部化
- 内容:
  - 「パス変数」セクション（4変数: agent_path, agent_name, findings_save_path, antipattern_catalog_path）
  - 「手順」セクション（分析エージェント定義ファイルの Read → 指示に従った分析実行）
  - 「返答フォーマット」セクション（ファイル保存後の成否報告のみ）

### 3. SKILL.md（修正）— Phase 1 返答解析の削除
**対応フィードバック**: I-5: Phase 1 返答フォーマットの軽量化, I-6: データフロー最適化

**変更内容**:
- Line 158: `分析完了後、以下の1行フォーマット**のみ**で返答してください（他の出力を含めないこと）: dim: {次元名}, critical: {N}, improvement: {M}, info: {K}` → 削除（テンプレート化に伴い不要）
- Line 176-178: 返答解析ロジック全体を削除
  - 削除対象: 「**返答の解析方法**: - 各サブエージェントの返答から `dim: ` で始まる行を抽出する - フォーマット不正...」
- Line 180-182: エラーハンドリングを簡素化
  - 現在: 「対応する findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）が存在する → 成功。findings ファイルが存在しない → 失敗。Task ツールの返答から例外情報（エラーメッセージの要約）を抽出し、該当次元は「分析失敗（{エラー概要}）」として扱う」
  - 改善後: 「各サブエージェントの成否は findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）の存在のみで判定する。ファイルが存在しない場合は「分析失敗」として扱う」
- Line 188-193: Phase 1 完了サマリの出力方法を変更
  - 現在: サブエージェント返答からパースした件数を表示
  - 改善後: findings ファイルを Grep で解析し件数を集計（`grep -c "^\### .* \[severity: critical\]" {findings_path}` 等）

### 4. SKILL.md（修正）— ID_PREFIX マッピングの明示化
**対応フィードバック**: I-3: Phase 1 の ID_PREFIX マッピングに dim_path との対応が暗黙的

**変更内容**:
- Line 120-127（dimensions テーブル直後）に dim_path → ID_PREFIX のマッピングテーブルを追加:
  ```
  | dim_path | ID_PREFIX | 次元名 |
  |----------|-----------|--------|
  | shared/instruction-clarity | IC | 指示明確性 |
  | evaluator/criteria-effectiveness | CE | 基準有効性 |
  | evaluator/scope-alignment | SA | スコープ整合性 |
  | evaluator/detection-coverage | DC | 検出カバレッジ |
  | producer/workflow-completeness | WC | ワークフロー完全性 |
  | producer/output-format | OF | 出力形式実現性 |
  | unclassified/scope-alignment | SA | スコープ整合性（軽量版） |
  ```
- Line 163-172（antipattern_catalog_path マッピング）は削除（上記テーブルに統合）

### 5. SKILL.md（修正）— Phase 0 Step 7a の削除対象ファイル明示化
**対応フィードバック**: I-2: Phase 0 Step 7a の audit-*.md パターンで resolved-issues.md も削除される

**変更内容**:
- Line 114: `rm -f .agent_audit/{agent_name}/audit-*.md` → `rm -f .agent_audit/{agent_name}/audit-IC.md .agent_audit/{agent_name}/audit-CE.md .agent_audit/{agent_name}/audit-SA.md .agent_audit/{agent_name}/audit-DC.md .agent_audit/{agent_name}/audit-WC.md .agent_audit/{agent_name}/audit-OF.md .agent_audit/{agent_name}/audit-approved.md` に変更

### 6. SKILL.md（修正）— Phase 2 Step 1-2 間の findings サマリ読み込み
**対応フィードバック**: I-7: Phase 2 Step 2 findings 抽出の効率化

**変更内容**:
- Line 209-214（findings 抽出ロジック）を以下に置換:
  - 「findings ファイルの先頭 10 行を Read（`limit: 10`）し、サマリヘッダ（`Total: {N} (critical: {C}, improvement: {I}, info: {K})`）を抽出する。サマリヘッダが存在しない場合は従来の全文 Read + パース方式にフォールバックする」
- Line 209 の Read 処理前に追加する分岐ロジック:
  ```
  各 findings ファイルに対し:
  1. 先頭 10 行を Read（`limit: 10`）
  2. `Total: ` パターンを検索
  3. 存在する場合: サマリから件数を抽出
  4. 存在しない場合: 全文 Read → 従来のパース処理
  ```

### 7-13. agents/**/*.md（修正）— findings ファイルサマリヘッダの追加
**対応フィードバック**: I-7: Phase 2 Step 2 findings 抽出の効率化

**変更内容（全次元エージェント共通）**:
- 各エージェント定義の「返答フォーマット」セクション末尾に以下を追加:
  ```
  ## Findings ファイルフォーマット

  {findings_save_path} への保存時、以下の形式で記述する:

  - **先頭行にサマリヘッダを記載**: `Total: {N} (critical: {C}, improvement: {I}, info: {K})`
  - 続けて各 severity セクション（`## 重大な問題`, `## 改善提案`, `## 情報提供`）を記載
  ```

### 14. SKILL.md（修正）— Phase 2 Step 3-4 間の改善適用確認
**対応フィードバック**: I-1: Phase 2 Step 3-4間の改善適用確認の追加

**変更内容**:
- Line 271（承認数0判定の直後）に以下を追加:
  ```
  承認数が 1 以上の場合: AskUserQuestion で「{承認数}件の指摘に基づいて改善を適用します。続行しますか？」を確認する。「いいえ」選択時は Phase 3 へ直行する
  ```

### 15. SKILL.md（修正）— Phase 2 Step 3 承認数0の Phase 3 出力分岐
**対応フィードバック**: I-9: Phase 2 Step 3 承認数0の場合のPhase 3出力

**変更内容**:
- Line 271 の直後に Phase 3 出力分岐を追加:
  ```
  承認数が 0 の場合、Phase 3 では以下のフォーマットで出力する:
  ```
  ## agent_audit 完了
  - エージェント: {agent_name}
  - ファイル: {agent_path}
  - グループ: {agent_group}
  - 分析次元: {dim_count}件（{各次元名}）
  - 検出: critical {N}件, improvement {M}件, info {K}件
  - 承認: 0/{total}件（全てスキップ）
  - 改善適用なし
  ```
  ```

## 削除推奨ファイル
| ファイル | 理由 | 対応フィードバック |
|---------|------|------------------|
| agent_audit_new/agent_bench/ （ディレクトリ全体） | agent_audit_new スキル内に agent_bench スキル全体が配置されておりファイルスコープ違反 | C-1 |

## 実装順序

1. **C-1: agent_bench ディレクトリ削除**
   - 理由: スコープ違反の解消（他の変更に影響なし）
   - 操作: `rm -rf .claude/skills/agent_audit_new/agent_bench/`

2. **I-8: Phase 1 プロンプト外部化**
   - 理由: テンプレート作成 → SKILL.md での参照追加の順序（依存関係）
   - 2a. templates/phase1-dimension-analysis.md を新規作成
   - 2b. SKILL.md Line 148-158 を外部テンプレート参照に変更

3. **I-3: dim_path → ID_PREFIX マッピング明示化**
   - 理由: 後続の変更（I-5, I-6, I-2）で参照される基礎データ
   - SKILL.md Line 120-127 直後にマッピングテーブル追加、Line 163-172 削除

4. **I-5, I-6: Phase 1 返答解析削除**
   - 理由: テンプレート外部化完了後に実施（テンプレート内容に影響）
   - SKILL.md Line 158, 176-182, 188-193 を変更

5. **I-2: Phase 0 Step 7a 削除対象明示化**
   - 理由: 独立した変更（ID_PREFIX マッピング完了後に実施）
   - SKILL.md Line 114 を変更

6. **I-7: findings サマリヘッダ機能追加**
   - 理由: エージェント定義 → SKILL.md の順序（エージェントが新フォーマットで出力 → SKILL.md が読み込む）
   - 6a. agents/**/*.md 全 7 ファイルに findings ファイルフォーマットセクション追加
   - 6b. SKILL.md Line 209-214 を変更

7. **I-1: Phase 2 Step 3-4 間の改善適用確認追加**
   - 理由: 独立した変更（UX 改善）
   - SKILL.md Line 271 直後に追加

8. **I-9: Phase 2 承認数0の Phase 3 出力分岐追加**
   - 理由: 独立した変更（出力フォーマット整備）
   - SKILL.md Line 271 直後に追加

## 注意事項
- I-8（テンプレート外部化）により SKILL.md の Phase 1 プロンプトが templates/phase1-dimension-analysis.md を参照するため、テンプレートファイルが存在しない状態で SKILL.md を変更すると Phase 1 が失敗する
- I-7（findings サマリヘッダ）はエージェント定義と SKILL.md の両方に変更が必要。エージェント定義のみ変更した場合、SKILL.md は従来の全文パース方式にフォールバックするため動作には影響しない（効率化効果のみ失われる）
- I-3（マッピングテーブル追加）により antipattern_catalog_path マッピングテーブル（Line 163-172）が削除されるため、Phase 1 の antipattern_catalog_path パス変数解決ロジックを dim_path マッピングテーブルから導出するように変更する必要がある
- C-1（agent_bench ディレクトリ削除）は analysis.md の「外部参照の検出」セクション（Line 58）で agent_bench ディレクトリが記載されているが、削除対象であるため影響なし
