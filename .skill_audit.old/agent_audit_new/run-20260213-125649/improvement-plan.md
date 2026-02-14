# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 0 perspective 検証とエラーハンドリングの改善 | C-1, C-7, I-2 |
| 2 | SKILL.md | 修正 | Phase 1B audit 結果検索ロジックの明確化 | C-3 |
| 3 | SKILL.md | 修正 | Phase 3 削除処理の除去 | C-4 |
| 4 | SKILL.md | 修正 | Phase 3 収束判定条件の参照箇所の修正 | I-1 |
| 5 | SKILL.md | 修正 | Phase 3 結果ファイルパス変数重複の削除 | I-4 |
| 6 | SKILL.md | 修正 | Phase 3 Read 重複の削除 | I-3 |
| 7 | SKILL.md | 修正 | Phase 3/4 エラーハンドリングの再試行回数制限 | C-5 |
| 8 | SKILL.md | 修正 | Phase 4 ベースライン失敗時の早期検出フロー | I-6 |
| 9 | SKILL.md | 修正 | Phase 6 プロンプト選択条件分岐の明確化 | C-6 |
| 10 | SKILL.md | 修正 | Phase 6A/6B 並列実行記述の修正 | I-5 |
| 11 | SKILL.md | 修正 | Phase 5→6A 冗長パス変数の削減 | I-7 |
| 12 | SKILL.md | 修正 | ワークフロー完了基準の明確化 | I-9 |
| 13 | templates/knowledge-init-template.md | 修正 | user_requirements 参照の修正 | C-2 |
| 14 | templates/knowledge-init-template.md | 修正 | 最新ラウンドサマリ構造の明示 | I-1 |
| 15 | templates/phase1a-variant-generation.md | 修正 | 返答フォーマットの固定行数化 | I-8 |
| 16 | templates/phase1b-variant-generation.md | 修正 | 返答フォーマットの固定行数化 | I-8 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**:
- C-1: Phase 0 perspective 検証失敗時のデータ損失
- C-7: Phase 0 reference_perspective 読み込み失敗時のフォールバック不完全
- I-2: Phase 0 perspective 自動生成のエラーハンドリング不足

**変更内容**:
- **行84**: `{reference_perspective_path}` の設定ロジック → `Read で確認できない場合は {reference_perspective_path} を空文字列とする` を追加
- **行88-95**: Step 3 サブエージェント指示 → 「サブエージェント失敗時はエラー出力してスキル終了」を追加
- **行114-127**: Step 5 再生成と Step 6 検証 → 「再生成時は一時ファイル `.agent_bench/{agent_name}/perspective-source.tmp.md` に保存し、検証成功後に perspective-source.md に移動する」に変更

### 2. SKILL.md（修正）
**対応フィードバック**: C-3: Phase 1B の audit 結果検索ロジックの曖昧性

**変更内容**:
- **行193-197**: 「最新ラウンドのファイルのみ抽出」 → 「Glob で `.agent_audit/{agent_name}/run-*/audit-*.md` を検索し、run-YYYYMMDD-HHMMSS ディレクトリ名を辞書順降順でソートして最新ディレクトリのファイルのみ使用する」に明確化

### 3. SKILL.md（修正）
**対応フィードバック**: C-4: Phase 3 削除処理の競合リスク

**変更内容**:
- **行222**: `rm -f .agent_bench/{agent_name}/results/v{NNN}-*.md` の削除処理を完全除去
- Phase 3 サブエージェント（templates/phase3-evaluation.md）に既存ファイル削除を任せる（Write 前の既存ファイル確認・削除）

### 4. SKILL.md（修正）
**対応フィードバック**: I-1: Phase 3 の収束判定条件の参照先の不明確性

**変更内容**:
- **行234**: 「knowledge.md の最新ラウンドサマリの convergence フィールドを参照」 → 「knowledge.md の `## 最新ラウンドサマリ` セクションを読み取り、convergence 行の値を判定する（書式: `convergence: {yes/no}`）」に明確化

### 5. SKILL.md（修正）
**対応フィードバック**: I-4: Phase 3 結果ファイル重複読み込み

**変更内容**:
- **行248-250**: パス変数定義の重複3行を削除し、行245-254 を以下に統合:
  ```
  - `{prompt_path}`: 評価対象プロンプトの絶対パス
  - `{test_doc_path}`: `.agent_bench/{agent_name}/test-document-round-{NNN}.md`
  - `{result_path}`: `.agent_bench/{agent_name}/results/v{NNN}-{name}-run{R}.md`
  - `{NNN}`: プロンプトのバージョン番号
  - `{name}`: プロンプトの名前部分
  - `{R}`: 実行回数（1 または 2）
  ```

### 6. SKILL.md（修正）
**対応フィードバック**: I-3: Phase 0 perspective 検証の Read 重複

**変更内容**:
- **行125**: 「生成された perspective を Read し」 → 「生成された perspective（サブエージェントコンテキストまたは一時ファイルから取得済み）」に変更し、Read を削除

### 7. SKILL.md（修正）
**対応フィードバック**: C-5: Phase 3/4 エラーハンドリングの未定義分岐

**変更内容**:
- **行259-262**: Phase 3 再試行処理 → 「最大2回まで再試行。2回目の再試行失敗時は選択肢を `除外して続行` と `中断` のみに制限」
- **行287-290**: Phase 4 再試行処理 → 「最大2回まで再試行。2回目の再試行失敗時は選択肢を `除外して続行` と `中断` のみに制限」

### 8. SKILL.md（修正）
**対応フィードバック**: I-6: Phase 4 ベースライン失敗時の早期検出不足

**変更内容**:
- **行273-284**: Phase 4 実行フローを以下に変更:
  1. ベースライン採点を最初に実行し、完了を待つ
  2. ベースライン採点失敗時は即座に中断（エラー出力してスキル終了）
  3. ベースライン採点成功時のみ、残りのプロンプト採点を並列実行
  4. 残りのプロンプト採点の成功/失敗を集計し、既存の分岐処理に進む

### 9. SKILL.md（修正）
**対応フィードバック**: C-6: Phase 6 プロンプト選択の条件分岐の不完全性

**変更内容**:
- **行332**: 選択肢の提示 → 「選択肢: 1. v{NNN}-baseline.md (ベースライン), 2. v{NNN}-variant-{name1}.md (バリアント1, 推奨), 3. v{NNN}-variant-{name2}.md (バリアント2)」のように明示的に番号付きで列挙
- **行334-346**: 条件分岐 → 「選択肢が `baseline` を含む場合は変更なし。それ以外の場合はデプロイフローに進む」に明確化

### 10. SKILL.md（修正）
**対応フィードバック**: I-5: Phase 6A と 6B の並列実行記述の誤り

**変更内容**:
- **行371-381**: ステップ2の実行順序を以下に変更:
  ```
  **A) ナレッジ更新（最初に実行）**
  （既存内容）

  **B) スキル知見フィードバック（A完了後に実行）**
  （既存内容）

  **C) 次アクション選択（B完了後に実行）**
  （既存内容。AskUserQuestion のため並列不可）

  A → B → C の順に直列実行する。
  ```

### 11. SKILL.md（修正）
**対応フィードバック**: I-7: Phase 5 から Phase 6A への情報伝達の冗長性

**変更内容**:
- **行353-359**: Phase 6A knowledge 更新のパス変数から `{recommended_name}`, `{judgment_reason}` を削除
- templates/phase6a-knowledge-update.md の行8-9 の指示を「{report_save_path} から recommended と reason を抽出する」に変更

### 12. SKILL.md（修正）
**対応フィードバック**: I-9: 完了基準の曖昧性

**変更内容**:
- **行8-11**: 完了基準を以下に変更:
  ```
  **構造最適化の完了基準**:
  - 以下のいずれかを満たす:
    1. 収束判定基準を満たす（scoring-rubric.md の収束判定参照）かつ推奨最低ラウンド数（3ラウンド）に達する
    2. ユーザーが Phase 6 ステップ2C で「終了」を選択する
  - 収束判定後もユーザー選択により追加ラウンド実行可能
  ```

### 13. templates/knowledge-init-template.md（修正）
**対応フィードバック**: C-2: Phase 1A/1B テンプレートへの未定義パス変数

**変更内容**:
- **行2-4**: 手順の変更 → 「Read で {perspective_source_path} を読み込み、`## 概要` セクションからエージェントの目的と要件を抽出する」に変更（{user_requirements} 変数の依存を除去）
- **行16**: `{perspective の概要から抽出した目的}` に統一

### 14. templates/knowledge-init-template.md（修正）
**対応フィードバック**: I-1: Phase 3 の収束判定条件の参照先の不明確性

**変更内容**:
- **行45-47**: 「最新ラウンドサマリ」セクションに構造を明示:
  ```
  ## 最新ラウンドサマリ

  （まだラウンドは実施されていません）

  （構造: 以下の行形式で記載）
  - round: {N}
  - scores: {各プロンプトの Mean(SD)}
  - recommended: {プロンプト名}
  - convergence: {yes/no}
  - key_findings: {主要知見1-2行}
  ```

### 15. templates/phase1a-variant-generation.md（修正）
**対応フィードバック**: I-8: サブエージェント返答フォーマットの可変性

**変更内容**:
- **行9-41**: 返答フォーマットを固定4行に変更し、詳細はファイルに保存:
  ```
  9. 構造分析結果とバリアント詳細を `.agent_bench/{agent_name}/phase1a-analysis.md` に保存する
  10. 以下のフォーマットで4行のみ返答する:

  agent_name: {agent_name}
  baseline_created: yes
  variants_created: 2
  analysis_saved: {phase1a-analysis.md への絶対パス}
  ```

### 16. templates/phase1b-variant-generation.md（修正）
**対応フィードバック**: I-8: サブエージェント返答フォーマットの可変性

**変更内容**:
- **行20-34**: 返答フォーマットを固定4行に変更し、詳細はファイルに保存:
  ```
  5. 選定プロセスとバリアント詳細を `.agent_bench/{agent_name}/phase1b-analysis-round-{NNN}.md` に保存する
  6. 以下のフォーマットで4行のみ返答する:

  mode: {Broad/Deep}
  baseline_copied: yes
  variants_created: 2
  analysis_saved: {phase1b-analysis-round-{NNN}.md への絶対パス}
  ```

## 新規作成ファイル

なし

## 削除推奨ファイル

なし

## 実装順序

1. **templates/knowledge-init-template.md の修正** (変更 #13, #14)
   - 理由: SKILL.md の Phase 0 でサブエージェント委譲されるため、テンプレート側を先に修正
   - 変更内容: user_requirements 依存除去、最新ラウンドサマリ構造の明示

2. **templates/phase1a-variant-generation.md, phase1b-variant-generation.md の修正** (変更 #15, #16)
   - 理由: SKILL.md の Phase 1A/1B でサブエージェント委譲されるため、テンプレート側を先に修正
   - 変更内容: 返答フォーマットの固定行数化

3. **templates/phase6a-knowledge-update.md の修正** (変更 #11 の一部)
   - 理由: SKILL.md の Phase 6A でパス変数削減の影響を受けるため、テンプレート側のパラメータ抽出ロジックを先に修正
   - 変更内容: recommended/reason を report_save_path から抽出

4. **SKILL.md の修正** (変更 #1〜#12)
   - 理由: 全テンプレート修正完了後、親ロジックを修正
   - 優先順位:
     a. Phase 0 の修正（#1）— perspective 解決とエラーハンドリング（C-1, C-7, I-2, I-3）
     b. Phase 1B の修正（#2）— audit 結果検索ロジック（C-3）
     c. Phase 3 の修正（#3, #4, #5, #6, #7）— 削除処理除去、収束判定、重複削除、再試行制限（C-4, C-5, I-1, I-3, I-4）
     d. Phase 4 の修正（#7, #8）— 再試行制限、ベースライン早期検出（C-5, I-6）
     e. Phase 5→6A の修正（#11）— パス変数削減（I-7）
     f. Phase 6 の修正（#9, #10）— プロンプト選択、並列実行記述修正（C-6, I-5）
     g. 完了基準の修正（#12）— ワークフロー完了条件の明確化（I-9）

## 注意事項
- Phase 3 の削除処理除去により、templates/phase3-evaluation.md にも既存ファイル削除ロジックの追加が必要（Write 前に既存ファイルチェック）
- Phase 0 Step 5 の再生成処理で一時ファイルパターン（.tmp.md）を使用するため、他フェーズで一時ファイルを誤って参照しないよう注意
- Phase 6A knowledge 更新テンプレートで report_save_path から推奨情報を抽出する処理が追加されるため、レポートフォーマットの安定性が前提条件となる
- ベースライン採点の早期検出により Phase 4 の実行フローが変わるため、並列実行パターンが「ベースライン（直列）→ 残りプロンプト（並列）」の2段階に変更される
