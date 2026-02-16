# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | templates/phase5-analysis-report.md | 修正 | パス変数に {prompts_dir} を追加 | C-1: Variation ID 情報欠落 |
| 2 | templates/phase6a-knowledge-update.md | 修正 | パス変数に {prompts_dir} を追加 | C-1: Variation ID 情報欠落 |
| 3 | SKILL.md | 修正 | Phase 5/6 で {prompts_dir} をパス変数に追加 | C-1: Variation ID 情報欠落 |
| 4 | SKILL.md | 修正 | Phase 0 Step 5 の再生成処理フローを明示化 | C-2: 再生成処理フロー欠落 |
| 5 | templates/phase6a-deploy.md | 修正 | デプロイ前の差分プレビューと最終確認を追加 | C-3: agent_path 上書き時のガード欠落 |
| 6 | SKILL.md | 修正 | Phase 6 Step 1 のデプロイ前確認手順を追加 | C-3: agent_path 上書き時のガード欠落 |
| 7 | SKILL.md | 修正 | Phase 0 の空ファイル・不足判定基準を明示化 | I-1: 入力バリデーション不足 |
| 8 | SKILL.md | 修正 | Phase 3 の収束判定達成済み判定手順を明記 | I-2: 収束判定達成済み判定の参照手順欠如 |
| 9 | templates/phase4-scoring.md | 修正 | result_run2_path 不在時の処理分岐を追加 | I-4: result_run2_path 不在時の処理フロー欠落 |
| 10 | test-document-guide.md | 修正 | セクション1-4のみ抽出してサブエージェント用ファイルに分割 | I-5: Phase 2 テスト文書生成でガイドファイル全文読み込み |
| 11 | templates/phase2-test-document.md | 修正 | test_document_guide_path を分割後のファイルに変更 | I-5: Phase 2 テスト文書生成でガイドファイル全文読み込み |
| 12 | templates/phase5-analysis-report.md | 修正 | パス変数に {past_scores} を追加し、knowledge.md 全文読み込みを削減 | I-6: Phase 5 で knowledge.md 全文読み込み |
| 13 | SKILL.md | 修正 | Phase 5 で {past_scores} を抽出して渡す処理を追加 | I-6: Phase 5 で knowledge.md 全文読み込み |

## 各ファイルの変更詳細

### 1. templates/phase5-analysis-report.md（修正）
**対応フィードバック**:
- C-1: Phase 5 から Phase 6 への Variation ID 情報欠落
- I-6: Phase 5 で knowledge.md 全文読み込み

**変更内容**:
- パス変数セクション: `{prompts_dir}` と `{past_scores}` を追加
- 手順1: `{knowledge_path}` の読み込みを削除し、`{past_scores}` を参照する記述に変更
- 手順2: `{prompts_dir}` からプロンプトファイルを読み込んで Variation ID を抽出する手順を追加
- 返答フォーマット L19: 「{prompt1}={Variation ID, 変更内容要約}」の構成で variants 行を生成する際、prompts/ ディレクトリから Variation ID を読み取る旨を追記

### 2. templates/phase6a-knowledge-update.md（修正）
**対応フィードバック**: C-1: Phase 5 から Phase 6 への Variation ID 情報欠落

**変更内容**:
- パス変数セクション: `{prompts_dir}` を追加
- 手順2 L12: 「バリエーションステータス」テーブルの更新処理に「{prompts_dir} から Variation ID を読み取る」手順を明記

### 3. SKILL.md（修正）
**対応フィードバック**:
- C-1: Phase 5 から Phase 6 への Variation ID 情報欠落
- C-2: Phase 0 Step 5 の再生成処理フロー欠落
- C-3: agent_path 上書き時のガード欠落
- I-1: 入力バリデーション不足
- I-2: 収束判定達成済み判定の参照手順欠如
- I-6: Phase 5 で knowledge.md 全文読み込み

**変更内容**:
- Phase 0 L42: 「agent_path の読み込み」の後に「空ファイルまたは frontmatter のみの場合、新規作成モードとみなして AskUserQuestion でヒアリング開始」分岐を追加
- Phase 0 L112: 「ユーザーが承認した場合」の後に、以下の処理を明記:
  - 「4件の批評結果（重大な問題・改善提案）を箇条書きで抽出し、{user_requirements} に追記する」
  - 「Phase 0 Step 3 と同じパターンで perspective を再生成する（1回のみ）」
  - 「再生成後、Phase 0 Step 6 の検証プロセスに進む」
- Phase 3 L224: 「収束判定が達成済みの場合」の前に「knowledge.md の最新ラウンドサマリの convergence フィールドを参照し、」を追加
- Phase 5 L289: パス変数に `{prompts_dir}` と `{past_scores}` を追加
  - `{past_scores}`: knowledge.md から「ラウンド別スコア推移」セクションを抽出したテキスト変数
- Phase 5 L289 の直前: 「knowledge.md を Read し、『ラウンド別スコア推移』セクションを抽出して {past_scores} に格納する」処理を追加
- Phase 6 Step 1 L322: 「ベースライン以外を選択した場合」の後、Task 実行前に以下を追加:
  - 「選択プロンプトと agent_path の差分を Bash diff で確認し、差分プレビューを表示する」
  - 「AskUserQuestion で『この変更をデプロイしますか?』を確認する」
  - 「承認された場合のみ Task を実行する」
- Phase 6 Step 2A L338: パス変数に `{prompts_dir}` を追加

### 4. templates/phase6a-deploy.md（修正）
**対応フィードバック**: C-3: agent_path 上書き時のガード欠落

**変更内容**:
- 手順1と2の間に以下を挿入:
  - 「Read で {agent_path} を読み込む」
  - 「{selected_prompt_path} の Benchmark Metadata ブロック除去版と {agent_path} の差分を比較し、変更箇所を提示する」
- 手順3（旧）を「Metadata 除去版を {agent_path} に Write で上書き保存する」に変更
- 注記: 「SKILL.md 側で差分プレビューと AskUserQuestion による承認が行われている前提」を追記

### 5. SKILL.md（修正）
**対応フィードバック**: I-3: Phase 0 perspective 批評結果の集約処理が暗黙的依存

**変更内容**:
- Phase 0 Step 4 L92-106: 各批評エージェントへのプロンプトに以下を追加:
  - 「批評結果を `.agent_bench/{agent_name}/perspective-critique-{critic_type}.md` に保存する」
  - critic_type: effectiveness, completeness, clarity, generality
- Phase 0 Step 5 L109: 「4件の批評から」の前に「Read で `.agent_bench/{agent_name}/perspective-critique-*.md` を読み込み、」を追加

### 6. templates/phase4-scoring.md（修正）
**対応フィードバック**: I-4: result_run2_path 不在時の処理フロー欠落

**変更内容**:
- 手順4（Run2結果の読み込み）の直後に以下を追加:
  - 「{result_run2_path} が存在しない場合（収束時）、Run1 のみ採点し、SD = N/A とする」
- 手順7（返答フォーマット L12）に分岐を追加:
  - 通常時: `Run1={X.X}(検出{X.X}+bonus{N}-penalty{N}), Run2={X.X}(検出{X.X}+bonus{N}-penalty{N})`
  - Run2 不在時: `Run1={X.X}(検出{X.X}+bonus{N}-penalty{N}), SD=N/A`

### 7. test-document-guide.md（修正）
**対応フィードバック**: I-5: Phase 2 テスト文書生成でガイドファイル全文読み込み

**変更内容**:
- 現在の test-document-guide.md を2ファイルに分割する:
  - **test-document-guide-subagent.md**（新規作成）: セクション1-4（入力型判定、基本構成、問題埋め込みガイドライン、正解キー生成）のみ抽出
  - **test-document-guide.md**（親用に残す）: セクション5-6（過去履歴の確認、ドメイン多様性ガイドライン）を保持し、セクション1-4 は削除して「詳細は test-document-guide-subagent.md を参照」に置換

### 8. templates/phase2-test-document.md（修正）
**対応フィードバック**: I-5: Phase 2 テスト文書生成でガイドファイル全文読み込み

**変更内容**:
- パス変数: `{test_document_guide_path}` → `{test_document_guide_subagent_path}` に変更
- 手順1: `{test_document_guide_path}` → `{test_document_guide_subagent_path}` に変更
- 手順2-4: 「test-document-guide.md」→ 「test-document-guide-subagent.md」に変更

### 9. SKILL.md（修正）
**対応フィードバック**: I-5: Phase 2 テスト文書生成でガイドファイル全文読み込み

**変更内容**:
- Phase 2 L200: パス変数 `{test_document_guide_path}` を `{test_document_guide_subagent_path}` に変更し、パスを `.claude/skills/agent_bench_new/test-document-guide-subagent.md` に更新

## 新規作成ファイル
| ファイル | 目的 | 対応フィードバック |
|---------|------|------------------|
| test-document-guide-subagent.md | Phase 2 サブエージェントが参照する最小限のガイド（セクション1-4のみ） | I-5: Phase 2 テスト文書生成でガイドファイル全文読み込み |
| templates/perspective/critic-save-template.md（任意） | 批評結果をファイル保存する際のテンプレート（既存の critic-*.md に保存処理を追加する場合は不要） | I-3: Phase 0 perspective 批評結果の集約処理が暗黙的依存 |

## 削除推奨ファイル
なし

## 実装順序
1. **test-document-guide-subagent.md 新規作成** — 分割元ファイル（test-document-guide.md）から抽出
2. **test-document-guide.md 修正** — セクション1-4 を削除して参照リンクに置換
3. **templates/phase2-test-document.md 修正** — 新規作成したファイルへのパス変更
4. **templates/phase4-scoring.md 修正** — Run2 不在時の処理分岐を追加（他ファイルへの依存なし）
5. **templates/phase5-analysis-report.md 修正** — パス変数追加（{prompts_dir}, {past_scores}）
6. **templates/phase6a-knowledge-update.md 修正** — パス変数追加（{prompts_dir}）
7. **templates/phase6a-deploy.md 修正** — 差分プレビュー処理追加
8. **SKILL.md 修正** — 全ての変更を統合（Phase 0 空ファイル判定、Phase 0 Step 5 再生成フロー、Phase 0 Step 4 批評結果保存、Phase 3 収束判定参照、Phase 5 パス変数追加と抽出処理、Phase 6 差分プレビュー、Phase 2 パス変更）

依存関係の検出方法:
- 改善1（test-document-guide-subagent.md 新規作成）の成果物を改善3（phase2-test-document.md）と改善8（SKILL.md Phase 2）が参照するため、改善1を最初に実施
- 改善5-7（テンプレート修正）の成果物を改善8（SKILL.md）が参照するため、テンプレート修正を先に実施
- 改善4, 5, 6, 7 は互いに独立しているため、順不同で実施可能

## 注意事項
- 変更によって既存のワークフローが壊れないこと
- 新規作成ファイル（test-document-guide-subagent.md）のパスが SKILL.md で正しく定義されていること
- {prompts_dir} パス変数の追加により、Phase 5/6 で Variation ID の読み取りが確実に行えること
- Phase 0 Step 5 の再生成処理は1回のみ実行し、無限ループを防ぐこと
- Phase 6 のデプロイ前確認は、ユーザーが明示的に承認した場合のみ実行すること
- result_run2_path が存在しない場合（収束時）、SD = N/A として扱い、Phase 5 の推奨判定で前回 SD を参照すること
- test-document-guide.md の分割により、サブエージェントが読み込む行数が 254行 → 約150行（セクション1-4のみ）に削減されること
- Phase 5 で knowledge.md の全文読み込みを {past_scores} テキスト変数に置換することで、サブエージェントのコンテキスト消費を削減すること
