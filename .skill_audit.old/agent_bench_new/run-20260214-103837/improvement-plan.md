# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | templates/perspective/critic-effectiveness.md | 修正 | 未定義プレースホルダ `{existing_perspectives_summary}` を削除 | C-1 |
| 2 | templates/perspective/critic-generality.md | 修正 | 未定義プレースホルダ `{existing_perspectives_summary}` を削除 | C-1 |
| 3 | SKILL.md | 修正 | Phase 0 Step 4 から未使用パス変数 `{agent_path}` を削除（critic-clarity.md 向け） | C-2 |
| 4 | SKILL.md | 修正 | Phase 1A から未使用パス変数 `{perspective_path}` を削除 | C-3 |

## 各ファイルの変更詳細

### 1. templates/perspective/critic-effectiveness.md（修正）
**対応フィードバック**: C-1: テンプレートのプレースホルダ未定義

**変更内容**:
- 行21-23のステップ3全体を削除:
  - 現在: `### ステップ3: 境界明確性の検証\n既存観点情報:\n{existing_perspectives_summary}\n\n- 評価スコープの5項目と既存観点のスコープを照合する...`
  - 改善後: セクションごと削除し、ステップ4を「ステップ3: 結論の導出」に番号変更

### 2. templates/perspective/critic-generality.md（修正）
**対応フィードバック**: C-1: テンプレートのプレースホルダ未定義

**変更内容**:
- 行22の `{existing_perspectives_summary}` プレースホルダ記述を削除:
  - 現在: `既存観点情報:\n{existing_perspectives_summary}\n\n- 評価スコープの5項目と既存観点のスコープを照合する`
  - 改善後: `- 評価スコープの5項目と既存観点のスコープを照合する`（プレースホルダ行を削除）

**注記**: critic-effectiveness.md では境界明確性の検証セクション全体が不要だが、critic-generality.md では既存観点との照合自体は有用なため、プレースホルダ行のみ削除

### 3. SKILL.md（修正）— Phase 0 Step 4
**対応フィードバック**: C-2: SKILL.md で定義されたパス変数がテンプレートで未使用

**変更内容**:
- 行92-95のパス変数リストから `{agent_path}` を削除:
  - 現在: `パス変数:\n- {perspective_path}: Step 3 で保存した perspective ファイルの絶対パス\n- {agent_path}: エージェント定義ファイルの絶対パス`
  - 改善後: `パス変数:\n- {perspective_path}: Step 3 で保存した perspective ファイルの絶対パス`

**理由**: critic-clarity.md, critic-completeness.md, critic-effectiveness.md, critic-generality.md のいずれも `{agent_path}` を参照していない

### 4. SKILL.md（修正）— Phase 1A
**対応フィードバック**: C-3: SKILL.md と Phase 1A テンプレートの不整合

**変更内容**:
- 行154-161のパス変数リストから `{perspective_path}` を削除:
  - 現在: `- {perspective_source_path}: \`.agent_bench/{agent_name}/perspective-source.md\` の絶対パス\n- {perspective_path}: \`.agent_bench/{agent_name}/perspective.md\` の絶対パス`
  - 改善後: `- {perspective_source_path}: \`.agent_bench/{agent_name}/perspective-source.md\` の絶対パス`（perspective_path 行を削除）

**理由**: phase1a-variant-generation.md テンプレートでは `{perspective_source_path}` のみ使用し、`{perspective_path}` は参照していない

## 新規作成ファイル
（なし）

## 削除推奨ファイル
（なし）

## 実装順序
1. **templates/perspective/critic-effectiveness.md** を修正（ステップ3削除、ステップ4を3に繰り上げ）
2. **templates/perspective/critic-generality.md** を修正（プレースホルダ行削除）
3. **SKILL.md の Phase 0 Step 4** を修正（{agent_path} 削除）
4. **SKILL.md の Phase 1A** を修正（{perspective_path} 削除）

依存関係:
- テンプレートファイルとSKILL.mdは独立しており、並行修正可能
- ただし、SKILL.md の2箇所の修正は同一ファイル内のため順序実行が必要（Phase 0 → Phase 1A の順に修正）

## 注意事項
- すべての変更はパス変数の削除であり、既存ワークフローを破壊しない
- 未定義プレースホルダの削除により、サブエージェント実行時のエラーリスクが低減される
- テンプレートの構造変更（critic-effectiveness.md のステップ番号繰り上げ）により、出力形式が一貫性を維持
