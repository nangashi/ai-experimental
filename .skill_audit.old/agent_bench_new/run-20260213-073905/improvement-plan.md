# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase別詳細を外部化し、415行→約165行に削減 | C-1, C-2, C-3 |
| 2 | scoring-rubric.md | 修正 | 収束判定基準を統一（3ラウンド→2ラウンド連続）し、改善率上限との競合を解消 | C-2 |
| 3 | templates/phase0-perspective-resolution.md | 修正 | 失敗理由を区別できる返答フォーマットを追加 | C-7 |
| 4 | templates/phase0-perspective-generation.md | 修正 | user_requirements のスコープと更新フローを明確化 | C-8 |
| 5 | templates/phase0-perspective-generation-simple.md | 修正 | user_requirements のスコープを明確化 | C-8 |
| 6 | templates/perspective/generate-perspective.md | 修正 | 1行返答フォーマットを明示 | C-4 |
| 7 | templates/phase3-error-handling.md | 修正 | サブエージェント化し、分岐判定のみ返答する設計に変更 | I-1 |
| 8 | templates/phase4-scoring.md | 修正 | Run単位の部分失敗処理とファイル不在処理を追加 | I-3 |
| 9 | templates/phase5-analysis-report.md | 修正 | 除外されたプロンプトのファイル不在時エラー処理と7行サマリフォーマット定義を追加 | I-4, I-9 |
| 10 | templates/phase6-step2-workflow.md | 修正 | Step 3の並列実行を逐次化（A→B順）に変更 | C-6, C-9 |
| 11 | templates/phase6-performance-table.md | 新規作成 | ラウンド別性能推移テーブル生成処理を追加 | C-3 |
| 12 | templates/phase1a-variant-generation.md | 修正 | サブエージェント失敗時のリトライフローを定義 | I-7 |
| 13 | templates/phase1b-variant-generation.md | 修正 | audit統合候補の空文字列ハンドリングを明示し、サブエージェント失敗時のリトライフローを定義 | C-5, I-7 |
| 14 | templates/phase6a-knowledge-update.md | 修正 | 却下後の再承認で再び却下された場合の動作を定義 | I-8 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**: [efficiency] C-1: SKILL.md が目標を超過

**変更内容**:
- **行40-398のPhase詳細記述を外部化**: 各 Phase の詳細ワークフローを個別ファイルに分割
  - 現在: 行40-137（Phase 0）, 行140-179（Phase 1A）, 行183-235（Phase 1B）等が SKILL.md に直接記述
  - 改善後: `templates/workflow-phase0.md`, `templates/workflow-phase1a.md`, `templates/workflow-phase1b.md` 等に分割し、SKILL.md には概要のみ記載
- **行18-24の成功基準を修正**: 収束判定を「3ラウンド連続」→「2ラウンド連続」に統一（scoring-rubric.md と一致）
  - 現在: `収束判定: 3ラウンド連続でベースラインが推奨された場合`
  - 改善後: `収束判定: 2ラウンド連続で改善幅 < 0.5pt の場合`
- **行400-414の最終サマリにラウンド別性能推移テーブル生成処理を追加**
  - 現在: テーブル生成処理が不在
  - 改善後: Phase 6 Step 1 で `templates/phase6-performance-table.md` を実行してテーブル生成

### 2. scoring-rubric.md（修正）
**対応フィードバック**: [effectiveness] C-2: 目的の明確性: 成功基準の一部が自己矛盾

**変更内容**:
- **行65-69の収束判定基準を修正**: SKILL.md の成功基準と統一し、改善率上限との競合を解消
  - 現在: `2ラウンド連続で改善幅 < 0.5pt` だが、SKILL.md では「3ラウンド連続」と矛盾
  - 改善後: `2ラウンド連続で改善幅 < 0.5pt` で統一し、改善率上限（初期スコア +15%）との競合を解消するルール追記
    - 例: 初期スコアが3.0ptの場合、+15% = 0.45pt となり収束判定閾値（0.5pt）を下回る。この場合は改善率上限到達を優先して「目標達成」と判定

### 3. templates/phase0-perspective-resolution.md（修正）
**対応フィードバック**: [stability] C-7: 条件分岐の完全性: フォールバック検索失敗時のエラーメッセージ不足

**変更内容**:
- **行22-23, 29の失敗返答を失敗理由別に分離**
  - 現在: Step 2でパターン不一致時とStep 3でファイル不在時の両方で同一の「失敗として返答し終了」
  - 改善後:
    - Step 2失敗時: `perspective 解決失敗: ファイル名パターン不一致（{agent_path}）`
    - Step 3失敗時: `perspective 解決失敗: フォールバックファイル不在（.claude/skills/agent_bench_new/perspectives/{target}/{key}.md）`

### 4. templates/phase0-perspective-generation.md（修正）
**対応フィードバック**: [stability] C-8: 参照整合性: SKILL.md で定義されていない変数を使用

**変更内容**:
- **行11-12の user_requirements のスコープを明確化**
  - 現在: user_requirements のスコープと更新フローが不明確
  - 改善後:
    - パス変数セクションに `{user_requirements}` を追加し、定義を明記: 「Phase 0 でエージェント定義が不足している場合に AskUserQuestion で収集した要件テキスト。エージェント定義が十分な場合は空文字列。」
    - Step 1 に user_requirements が空文字列の場合のハンドリングを追記: 「{user_requirements} が空文字列の場合、AskUserQuestion をスキップし {agent_path} の内容のみを使用する」

### 5. templates/phase0-perspective-generation-simple.md（修正）
**対応フィードバック**: [stability] C-8: 参照整合性: SKILL.md で定義されていない変数を使用

**変更内容**:
- **パス変数セクションに user_requirements の定義を追加**
  - 現在: user_requirements のスコープが不明確
  - 改善後: `{user_requirements}`: Phase 0 でエージェント定義が不足している場合に AskUserQuestion で収集した要件テキスト。エージェント定義が十分な場合は空文字列。」

### 6. templates/perspective/generate-perspective.md（修正）
**対応フィードバック**: [stability] C-4: 出力フォーマット決定性: サブエージェント返答の行数指定に曖昧性

**変更内容**:
- **行61-67の返答フォーマットに行数制限を明示**
  - 現在: 「以下のフォーマットで結果サマリのみ返答する」と記載されているが行数指定なし
  - 改善後: 「**以下の4行のみを返答してください**（他のテキストは含めない）:」に変更

### 7. templates/phase3-error-handling.md（修正）
**対応フィードバック**: [efficiency] I-1: Phase 3 の親コンテキスト保持

**変更内容**:
- **全45行をサブエージェント化し、分岐判定のみ返答する設計に変更**
  - 現在: 親スキルが直接実行する手順書（45行）
  - 改善後:
    - サブエージェント用テンプレートに変更し、冒頭に「以下の手順でエラーハンドリングを実行してください:」を追加
    - パス変数セクションを追加: `{evaluation_results}`: 各サブエージェントの成功/失敗ステータス（JSON配列）
    - 返答フォーマットを定義: 分岐判定結果のみ1行で返答（例: `phase4_proceed: all_success`, `retry_baseline`, `exclude_variants: v002-variant-minimal`）

### 8. templates/phase4-scoring.md（修正）
**対応フィードバック**: [effectiveness] I-3: エッジケース処理記述: Phase 3 の部分失敗時の Run 単位情報が phase4-scoring.md に伝達されない

**変更内容**:
- **行4にRun単位ファイル不在時の処理を追加**
  - 現在: Run1/Run2の両方が存在する前提
  - 改善後: 手順4と5の間に以下を追加:
    - 「4.5. Run1またはRun2のファイルが存在しない場合、存在するRunのみでスコア計算し、SDを N/A とする」
    - 「4.6. 両Runとも存在しない場合、エラーメッセージを返答して終了: `採点失敗: {prompt_name} の評価結果が存在しません`」

### 9. templates/phase5-analysis-report.md（修正）
**対応フィードバック**: [effectiveness] I-4: データフロー妥当性: Phase 5 で参照する scoring_file_paths が Phase 4 で除外されたプロンプトを含む可能性、[stability] I-9: 出力フォーマット決定性: Phase 5 の7行サマリのフォーマット詳細が不明確

**変更内容**:
- **行6の採点結果ファイル読み込み時にファイル不在エラー処理を追加**
  - 現在: ファイル不在時の処理が未定義
  - 改善後: 手順1に追記: 「{scoring_file_paths} のファイルが存在しない場合、エラーメッセージを出力して終了: `採点ファイル不在: {ファイルパス}（Phase 4 で除外された可能性があります）`」
- **行6-21の7行サマリフォーマットを明確化**
  - 現在: テンプレートにフォーマット定義がなく、順序が不明確
  - 改善後: 手順6に以下を追記:
    - 「**以下の7行を厳密にこの順序で返答してください**（各行: `key: value` の形式）:」
    - 各行のキー名と値の型を明示（例: `recommended: {プロンプト名（文字列）}`）

### 10. templates/phase6-step2-workflow.md（修正）
**対応フィードバック**: [stability] C-6: 冪等性: knowledge.md 更新時の並行実行リスク、[effectiveness] C-9: データフロー妥当性: Phase 6 Step 2の並列実行で次アクション選択の依存関係が不明確

**変更内容**:
- **行51-86のStep 3並列実行を逐次実行に変更**
  - 現在: A) proven-techniques.md 更新と B) 次アクション選択を並列実行
  - 改善後:
    - 見出し変更: `### Step 3: スキル知見フィードバックと次アクション選択（並列実行）` → `### Step 3: スキル知見フィードバック（逐次実行）`
    - 手順変更:
      1. A) proven-techniques.md 更新を実行（Task ツール）
      2. A) の完了を待つ
      3. B) 次アクション選択を実行（AskUserQuestion）
    - 行82-85の「A) の完了を待ってから」を削除（逐次実行のため不要）

### 11. templates/phase6-performance-table.md（新規作成）
**対応フィードバック**: [effectiveness] C-3: 欠落ステップ: Phase 6 最終サマリに記載された「ラウンド別性能推移テーブル」の生成処理が不在

**変更内容**:
- **新規作成**: ラウンド別性能推移テーブル生成処理を実装
  - パス変数: `{knowledge_path}`, `{phase5_summary}`, `{round_number}`
  - 手順:
    1. Read で knowledge.md を読み込み、`## ラウンド別スコア推移` セクションを抽出
    2. Phase 5 のサマリからデプロイ情報を抽出
    3. 各ラウンドのスコアから効果判定（EFFECTIVE: 改善幅 >= 0.5pt, INEFFECTIVE: < 0.5pt）を算出
    4. 表形式（`| Round | Best Score | Δ from Initial | Applied Technique | Result |`）でテーブル生成
  - 返答フォーマット: テーブル全体（markdown形式）

### 12. templates/phase1a-variant-generation.md（修正）
**対応フィードバック**: [stability] I-7: 冪等性: バリアント生成時の既存ファイル確認のタイミング

**変更内容**:
- **サブエージェント失敗時のリトライフローを定義**
  - 現在: サブエージェント失敗時のリトライフローが未定義
  - 改善後: 末尾に以下のセクションを追加:
    ```
    ## サブエージェント失敗時の処理
    - 失敗理由を分析し、以下に該当する場合は1回のみ再試行:
      - ファイル書き込みエラー（ディレクトリ不在等）
      - 一時的なツールエラー
    - それ以外の失敗（バリアント生成ロジックの問題等）は再試行せず、失敗として返答
    ```

### 13. templates/phase1b-variant-generation.md（修正）
**対応フィードバック**: [stability] C-5: 参照整合性: 存在しないディレクトリへの参照、[stability] I-7: 冪等性: バリアント生成時の既存ファイル確認のタイミング

**変更内容**:
- **audit パス変数が空文字列の場合のデフォルト動作を明記**
  - 現在: Glob 実行時にファイルが見つからない場合の動作が不明確
  - 改善後: パス変数セクションに以下を追記:
    - 「{audit_dim1_path}, {audit_dim2_path}: agent_audit の出力ファイルパス。ファイルが見つからない場合は空文字列 `""` として渡される。サブエージェントは空文字列の場合、そのファイルの読み込みをスキップし、`## Audit 統合候補` セクションを省略すること。」
- **サブエージェント失敗時のリトライフローを定義**（phase1a と同じ内容）

### 14. templates/phase6a-knowledge-update.md（修正）
**対応フィードバック**: [stability] I-8: 条件分岐の完全性: Phase 6 Step 2 の knowledge.md 更新承認で却下後の再承認フローが不明確

**変更内容**:
- **却下後の再承認で再び却下された場合の動作を明示**
  - 現在: 再承認で再び却下された場合の動作が未定義
  - 改善後: 手順末尾に以下を追記:
    - 「注: 再承認で再び却下された場合、エラーメッセージを出力してスキルを終了する: `knowledge.md 更新の承認を2回却下されたため、スキルを終了します。手動で knowledge.md を確認・修正してください。`」

## 新規作成ファイル
| ファイル | 目的 | 対応フィードバック |
|---------|------|------------------|
| templates/workflow-phase0.md | Phase 0 詳細（SKILL.md 行40-137を外部化） | C-1 |
| templates/workflow-phase1a.md | Phase 1A 詳細（SKILL.md 行140-179を外部化） | C-1 |
| templates/workflow-phase1b.md | Phase 1B 詳細（SKILL.md 行183-235を外部化） | C-1 |
| templates/workflow-phase2.md | Phase 2 詳細（SKILL.md 行239-257を外部化） | C-1 |
| templates/workflow-phase3.md | Phase 3 詳細（SKILL.md 行261-289を外部化） | C-1 |
| templates/workflow-phase4.md | Phase 4 詳細（SKILL.md 行293-326を外部化） | C-1 |
| templates/workflow-phase5.md | Phase 5 詳細（SKILL.md 行330-343を外部化） | C-1 |
| templates/workflow-phase6.md | Phase 6 詳細（SKILL.md 行347-398を外部化） | C-1 |
| templates/phase6-performance-table.md | ラウンド別性能推移テーブル生成 | C-3 |

## 削除推奨ファイル
なし

## 実装順序
1. **templates/phase6-performance-table.md を新規作成** — SKILL.md の Phase 6 詳細外部化で参照されるため先に作成
2. **templates/workflow-phase*.md を新規作成** — SKILL.md から外部化する Phase 詳細を格納
3. **SKILL.md を修正** — Phase 詳細を外部化し、収束判定基準を統一し、最終サマリにテーブル生成処理を追加
4. **scoring-rubric.md を修正** — 収束判定基準を統一し、改善率上限との競合を解消
5. **templates/phase0-perspective-resolution.md を修正** — 失敗理由別の返答フォーマットを追加
6. **templates/phase0-perspective-generation.md, templates/phase0-perspective-generation-simple.md を修正** — user_requirements のスコープを明確化
7. **templates/perspective/generate-perspective.md を修正** — 返答行数を明示
8. **templates/phase3-error-handling.md を修正** — サブエージェント化
9. **templates/phase4-scoring.md を修正** — Run単位の部分失敗処理を追加
10. **templates/phase5-analysis-report.md を修正** — ファイル不在エラー処理と7行サマリフォーマットを追加
11. **templates/phase6-step2-workflow.md を修正** — 並列実行を逐次化
12. **templates/phase1a-variant-generation.md, templates/phase1b-variant-generation.md を修正** — リトライフローと空文字列ハンドリングを追加
13. **templates/phase6a-knowledge-update.md を修正** — 再承認で却下された場合の動作を明示

依存関係の検出方法:
- テンプレート新規作成（1, 2）→ SKILL.md でのテンプレート参照追加（3）→ 1, 2 が先
- SKILL.md の修正（3）が scoring-rubric.md（4）と相互参照のため、3 → 4 の順序

## 注意事項
- 変更によって既存のワークフローが壊れないこと
- テンプレート外部化の場合、SKILL.md の参照箇所も同時に更新すること
- 新規テンプレートのパス変数が SKILL.md で定義されていること
- Phase 詳細外部化後、SKILL.md は概要のみを記載し、各 Phase の詳細は `templates/workflow-phase*.md` を Read で読み込む指示を追加すること
