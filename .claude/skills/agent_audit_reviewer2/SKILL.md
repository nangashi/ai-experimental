---
allowed-tools: Glob, Grep, Read, Write, Edit, Task, AskUserQuestion
description: 2文書交差検証＋回帰加重スコアリングでレビュー系エージェント定義を反復最適化するスキル
disable-model-invocation: true
---

レビュー系エージェント定義ファイルのプロンプトを OPRO 式エラー駆動ループで反復最適化します。2つの固定テスト文書（異なるドメイン）に対する検出性能を評価し、カテゴリ別回帰検出を組み込んだスコアリングで「注意力再配分トラップ」を構造的に抑制します。

## 使い方

```
/agent_audit_reviewer2 <file_path>
```

- `file_path`: レビュー系エージェント定義ファイルのパス（必須）

## v1 (agent_audit_reviewer) からの主要な改善

1. **2文書交差検証**: 異なるドメインのテスト文書2つで評価し、過適合を防止
2. **回帰加重スコアリング**: カテゴリ別検出率の回帰を1.5倍ペナルティで抑制
3. **制約なしメタインプルーバー**: S1-S5戦略メニュー廃止、エラー分析からの自由生成
4. **識別力による対象選定**: 床/天井問題を識別し、改善可能な問題に注力
5. **自己完結型**: agent_bench への依存を排除

## コンテキスト節約の原則

1. 参照ファイルは使用する Phase でのみ読み込む
2. 大量コンテンツの生成はサブエージェントに委譲する
3. サブエージェントからの返答は最小限にする（詳細はファイルに保存）
4. 親コンテキストには要約・メタデータのみ保持する
5. サブエージェント間のデータ受け渡しはファイル経由で行う

## ワークフロー

Phase 0 で2つの固定テスト文書を生成しベースラインを評価する。Phase 1（メタインプルーバー）→ Phase 2（評価）→ Phase 3（採点+分析）→ Phase 4（選択+更新）を繰り返す。

---

### Phase 0: 初期化・ベースライン評価

#### エージェントファイルの読み込み

1. 引数から `agent_path` を取得する（未指定の場合は `AskUserQuestion` で確認）
2. Read で `agent_path` を読み込む。失敗時はエラー出力して終了

#### agent_name の導出

3. `{agent_name}` を以下のルールで導出する:
   - `.claude/` 配下: `.claude/` からの相対パスの拡張子除去
   - それ以外: プロジェクトルートからの相対パスの拡張子除去

#### パースペクティブの解決

4. perspective ファイルを以下の順序で検索する:
   a. `.agent_audit_reviewer2/{agent_name}/perspective-source.md` を Read で確認する
   b. 見つからない場合: `.agent_audit_reviewer/{agent_name}/perspective-source.md` を Read で確認する（v1 からの移行用）
   c. 見つかった場合: `.agent_audit_reviewer2/{agent_name}/perspective-source.md` に Write でコピーする（b の場合のみ）
   d. いずれも見つからない場合: パースペクティブ自動生成（後述）を実行する

5. perspective-source.md から「## 問題バンク」セクション以降を除いた内容を `.agent_audit_reviewer2/{agent_name}/perspective.md` に Write で保存する

#### パースペクティブ自動生成（perspective 未検出の場合）

**Step 1: 要件抽出**
- エージェント定義の目的、評価基準、入力/出力の型、スコープ情報を `{user_requirements}` として構成する
- 情報不足の場合は `AskUserQuestion` でヒアリングする

**Step 2: perspective 初期生成**
`Task`（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_audit_reviewer2/templates/generate-perspective.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{agent_path}`: エージェント定義ファイルの絶対パス
- `{user_requirements}`: Step 1 で構成したテキスト
- `{perspective_save_path}`: `.agent_audit_reviewer2/{agent_name}/perspective-source.md` の絶対パス
- `{reference_perspective_path}`: 空

**Step 3: 批判レビュー（4並列）**
4つの `Task` を同一メッセージ内で並列起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

各エージェントへの指示:
`.claude/skills/agent_audit_reviewer2/templates/critic-perspective.md` を Read で読み込み、その内容に従って処理を実行してください。テンプレート内の `{focus_area}` を以下の値に置換してください。
- `{perspective_path}`: Step 2 で保存した perspective の絶対パス
- `{agent_path}`: エージェント定義ファイルの絶対パス

| サブエージェント | {focus_area} |
|---------------|-------------|
| 1 | effectiveness |
| 2 | completeness |
| 3 | clarity |
| 4 | generality |

**Step 4: フィードバック統合・再生成**
- 4件の批評から「重大な問題」「改善提案」を分類する
- 重大な問題または改善提案がある場合: フィードバックを `{user_requirements}` に追記し Step 2 を再実行する（1回のみ）
- 改善不要の場合: 現行 perspective を維持する

**Step 5: 検証**
- 必須セクション（`## 概要`, `## 評価スコープ`, `## スコープ外`, `## ボーナス/ペナルティの判定指針`, `## 問題バンク`）の存在を確認する
- 失敗 → エラー出力してスキル終了

#### 状態検出

6. `.agent_audit_reviewer2/{agent_name}/history.md` を Read で読み込む
   - **読み込み成功** → 継続モード。`{current_round}` を取得し、`{round_number}` = `{current_round}` + 1 として Phase 1 へ
   - **読み込み失敗** → 初回モード。Step 7 以降を実行する

#### ドメイン選択（初回のみ）

7. 2つの異なるドメインを選択する。例: 医療 + EC、金融 + 教育、SaaS + IoT など。

#### 固定テスト文書生成（初回のみ・2文書並列）

8. 2つの `Task` を同一メッセージ内で並列起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

各サブエージェントへの指示:
`.claude/skills/agent_audit_reviewer2/templates/init-test-document.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{test_document_guide_path}`: `.claude/skills/agent_audit_reviewer2/test-document-guide.md` の絶対パス
- `{perspective_path}`: `.agent_audit_reviewer2/{agent_name}/perspective.md` の絶対パス
- `{perspective_source_path}`: `.agent_audit_reviewer2/{agent_name}/perspective-source.md` の絶対パス

| 文書 | {domain} | {test_document_save_path} | {answer_key_save_path} |
|------|----------|--------------------------|----------------------|
| 文書1 | {domain1} | `.agent_audit_reviewer2/{agent_name}/test-document-1.md` | `.agent_audit_reviewer2/{agent_name}/answer-key-1.md` |
| 文書2 | {domain2} | `.agent_audit_reviewer2/{agent_name}/test-document-2.md` | `.agent_audit_reviewer2/{agent_name}/answer-key-2.md` |

#### テスト文書の品質検証（初回のみ・2文書並列）

9. 2つの `Task` を同一メッセージ内で並列起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_audit_reviewer2/templates/validate-test-document.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{test_document_path}`: 各文書のパス
- `{answer_key_path}`: 各正解キーのパス
- `{perspective_path}`: `.agent_audit_reviewer2/{agent_name}/perspective.md` の絶対パス

FAIL の場合: 問題詳細を追記して Step 8 のテスト文書生成を再実行する（1回のみ）。再検証でも FAIL の場合はエラー出力して終了。

#### ベースラインコピーと評価（初回のみ）

10. エージェント定義ファイルを Read し、先頭に Benchmark Metadata コメントを付与して `.agent_audit_reviewer2/{agent_name}/prompts/v001-baseline.md` に Write で保存する

11. v001-baseline を 2文書×2回 = 4回並列で評価する。4つの `Task` を同一メッセージ内で起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

各サブエージェントへの指示:
```
以下の手順でタスクを実行してください:
1. Read で {prompt_path} を読み込み、その内容に従ってタスクを実行してください
2. Read で {test_doc_path} を読み込み、処理対象としてください
3. 処理結果を Write で {result_path} に保存してください
4. 最後に「保存完了: {result_path}」とだけ返答してください
```

全タスク共通: `{prompt_path}` = `.agent_audit_reviewer2/{agent_name}/prompts/v001-baseline.md`

| タスク | {test_doc_path} | {result_path} |
|--------|----------------|---------------|
| 1 | test-document-1.md | results/v001-baseline-doc1-run1.md |
| 2 | test-document-1.md | results/v001-baseline-doc1-run2.md |
| 3 | test-document-2.md | results/v001-baseline-doc2-run1.md |
| 4 | test-document-2.md | results/v001-baseline-doc2-run2.md |

#### ベースライン採点（初回のみ・2文書並列）

12. 2つの `Task` を同一メッセージ内で起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_audit_reviewer2/templates/scoring.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{scoring_rubric_path}`: `.claude/skills/agent_audit_reviewer2/scoring-rubric.md` の絶対パス
- `{perspective_path}`: `.agent_audit_reviewer2/{agent_name}/perspective.md` の絶対パス

| 文書 | {answer_key_path} | {result_run1_path} | {result_run2_path} | {doc_label} | {scoring_save_path} |
|------|-------------------|--------------------|--------------------|-------------|-------------------|
| 文書1 | answer-key-1.md | results/v001-baseline-doc1-run1.md | results/v001-baseline-doc1-run2.md | doc1 | results/v001-baseline-doc1-scoring.md |
| 文書2 | answer-key-2.md | results/v001-baseline-doc2-run1.md | results/v001-baseline-doc2-run2.md | doc2 | results/v001-baseline-doc2-scoring.md |

`{prompt_name}`: v001-baseline

#### 統合スコア計算（親で実行）

13. 2つの採点ファイルを Read し、4つの Run スコアを取得して統合スコアを計算する:
   - `overall_mean = average(doc1_run1, doc1_run2, doc2_run1, doc2_run2)`
   - `overall_sd = stddev(doc1_run1, doc1_run2, doc2_run1, doc2_run2)`
   - `cross_doc_gap = |doc1_mean - doc2_mean|`
   - カテゴリ別検出率 = 2文書のカテゴリ別検出率を合算

#### 識別力判定（初回のみ・親で実行）

14. 2文書の採点ファイルの検出マトリクスから各問題の Run 結果を取得し、識別力を判定する:
   - **天井**: 全 Run で ○ → 識別力「低（天井）」
   - **床**: 全 Run で × → 識別力「低（床）」
   - **安定検出**: 大半が ○、残りが △ → 識別力「中」
   - **変動あり**: ○/△/× が混在 → 識別力「高」
   - **安定未検出**: 大半が ×、残りが △ → 識別力「中」

#### history.md の初期化（初回のみ）

15. 以下のフォーマットで history.md を Write する:

```markdown
# Optimization History: {agent_name}

## Agent Info
- Path: {agent_path}
- Test Documents: doc1={domain1} ({line_count1} lines), doc2={domain2} ({line_count2} lines)
- Initial Score: {overall_mean} (SD={overall_sd})
- Current Best: v001-baseline ({overall_mean})
- Rounds: 0

## Category Detection Rates
| Category | Rate | Detail |
|----------|------|--------|
| {cat1} | {rate} | ○{N}/△{N}/×{N} |
...

## Item Discrimination
### Doc1
| ID | Category | Severity | Difficulty | Run1 | Run2 | Discrimination |
|----|----------|----------|------------|------|------|---------------|
...

### Doc2
| ID | Category | Severity | Difficulty | Run1 | Run2 | Discrimination |
|----|----------|----------|------------|------|------|---------------|
...

Summary: 識別力高={N}問, 中={N}問, 低（天井）={N}問, 低（床）={N}問

## Current Error Analysis

{2文書の採点ファイルのエラー分析を統合}

## Round History
| Round | Best | Score | SD | cross_doc_gap | Key Change | Category Regressions |
|-------|------|-------|----|---------------|------------|---------------------|
| R0 | v001-baseline | {mean} | {sd} | {gap} | (initial) | - |

## Effective Changes
| Change | Effect (pt) | SD | Round | Target Category | Regressions |
|--------|-------------|-----|-------|----------------|-------------|

## Ineffective Changes
| Change | Effect (pt) | SD | Round | Target Category | Regressions |
|--------|-------------|-----|-------|----------------|-------------|
```

`{round_number}` = 1 に設定する。

テキスト出力:
```
## Phase 0: 初期化
- エージェント: {agent_name} ({agent_path})
- パースペクティブ: {既存 / 自動生成}
- テスト文書: doc1={domain1}({行数}行), doc2={domain2}({行数}行)
- ベースラインスコア: Mean={X.X}, SD={X.X}, cross_doc_gap={X.X}
- 識別力: 高={N}問, 中={N}問, 天井={N}問, 床={N}問
- 次フェーズ: Phase 1 (Round 1)
```

---

### Phase 1: Improve（メタインプルーバー）

現在のベストプロンプトのパスを決定する:
- Round 1: `{agent_path}`（元のエージェント定義ファイル）
- Round 2+: history.md の「Current Best」からプロンプトファイル名を取得し、`.agent_audit_reviewer2/{agent_name}/prompts/` 配下の絶対パスに解決する

`Task`（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_audit_reviewer2/templates/meta-improver.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{current_best_path}`: 現在のベストプロンプトの絶対パス
- `{history_path}`: `.agent_audit_reviewer2/{agent_name}/history.md` の絶対パス
- `{proven_insights_path}`: `.claude/skills/agent_audit_reviewer2/proven-insights.md` の絶対パス
- `{perspective_path}`: `.agent_audit_reviewer2/{agent_name}/perspective.md` の絶対パス
- `{prompts_dir}`: `.agent_audit_reviewer2/{agent_name}/prompts` の絶対パス
- `{round_number}`: 現在のラウンド番号

返答からバリアント名リストを抽出する。返答をテキスト出力し、Phase 2 へ。

---

### Phase 2: 並列評価実行

テキスト出力:
```
## Phase 2: 並列評価実行 (Round {round_number})
- 評価タスク数: {2バリアント × 2文書 × 2回 = 8}
```

2バリアント × 2文書 × 2回 = 8つの `Task` を同一メッセージ内で並列起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

各サブエージェントへの指示:
```
以下の手順でタスクを実行してください:
1. Read で {prompt_path} を読み込み、その内容に従ってタスクを実行してください
2. Read で {test_doc_path} を読み込み、処理対象としてください
3. 処理結果を Write で {result_path} に保存してください
4. 最後に「保存完了: {result_path}」とだけ返答してください
```

- `{prompt_path}`: `.agent_audit_reviewer2/{agent_name}/prompts/v{NNN}-variant-{name}.md`
- `{test_doc_path}`: test-document-1.md または test-document-2.md
- `{result_path}`: `results/v{NNN}-{name}-doc{D}-run{R}.md`

全タスク完了後:
- **全成功**: Phase 3 へ
- **一部失敗だが各バリアント・文書に最低1回の成功がある**: 警告出力し Phase 3 へ
- **いずれかのバリアント・文書で成功結果が0**: `AskUserQuestion` で確認（再試行 / 除外 / 中断）

---

### Phase 3: 採点 + 分析

#### Step 3.1: バリアント採点（2バリアント × 2文書 = 4並列）

4つの `Task` を同一メッセージ内で起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_audit_reviewer2/templates/scoring.md` を Read で読み込み、その内容に従って処理を実行してください。

各バリアント × 各文書に対して:
- `{answer_key_path}`: 対応する answer-key-{D}.md
- `{result_run1_path}`, `{result_run2_path}`: 対応する結果ファイル
- `{prompt_name}`: バリアント名
- `{doc_label}`: doc1 / doc2
- `{scoring_save_path}`: `results/v{NNN}-{name}-doc{D}-scoring.md`

#### Step 3.2: 統合スコア計算（親で実行）

各バリアントの4採点ファイルから統合スコアを計算する:
- `overall_mean`, `overall_sd`, `cross_doc_gap`
- カテゴリ別検出率（2文書合算）

history.md を Read し、現在ベストのスコアとカテゴリ別検出率を取得する。
各バリアントのカテゴリ別検出率を現在ベストと比較し、回帰（0.15以上の低下）を検出する。
回帰加重差分を計算する:
```
adjusted_diff = (variant_mean - current_best_mean) - 1.5 × Σ(regressed_category_rate_drops)
```

#### Step 3.3: 比較レポート生成

`Task`（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_audit_reviewer2/templates/analysis-report.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{scoring_rubric_path}`: `.claude/skills/agent_audit_reviewer2/scoring-rubric.md` の絶対パス
- `{history_path}`: `.agent_audit_reviewer2/{agent_name}/history.md` の絶対パス
- `{scoring_file_paths}`: 今回の全バリアントの採点ファイルパス（4ファイル）
- `{prompt_file_paths}`: 今回の全バリアントのプロンプトファイルパス
- `{report_save_path}`: `.agent_audit_reviewer2/{agent_name}/reports/round-{NNN}-comparison.md`

返答をテキスト出力してユーザーに提示。Phase 4 へ。

---

### Phase 4: プロンプト選択・更新・次アクション

#### ステップ1: プロンプト選択とデプロイ

history.md を Read し、Round History から過去ラウンドのスコアデータを取得する。

`AskUserQuestion` でユーザーに提示する:

```
## 性能推移
| Round | Best | Score | SD | cross_doc_gap | Category Regressions |
|-------|------|-------|----|---------------|---------------------|
| R0    | baseline | {X.X} | {X.X} | {X.X} | - |
| ...   | ...      | ...   | ...   | ...   | ... |

初期スコア: {初期値} → 現在ベスト: {現在値} (改善: +{差分}pt, +{改善率}%)
```

選択肢: 現在のベスト + 評価した全バリアント名。推奨に「(推奨)」を付記。

ユーザーの選択に応じて:
- **バリアント選択**: `Task`（`subagent_type: "general-purpose"`, `model: "haiku"`）でデプロイ:
  ```
  以下の手順でプロンプトをデプロイしてください:
  1. Read で {selected_prompt_path} を読み込む
  2. ファイル先頭の <!-- Benchmark Metadata ... --> ブロックを除去する
  3. {agent_path} に Write で上書き保存する
  4. 「デプロイ完了: {agent_path}」とだけ返答する
  ```
  - `{selected_prompt_path}`: ユーザーが選択したバリアントの `.agent_audit_reviewer2/{agent_name}/prompts/` 配下のファイルパス
  - `{agent_path}`: Phase 0 で取得したエージェント定義ファイルのパス
- **現在ベスト選択**: 変更なし

#### ステップ2: ナレッジ更新・次アクション

**A) history.md 更新**（先に完了を待つ）

`Task`（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_audit_reviewer2/templates/history-update.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{history_path}`: `.agent_audit_reviewer2/{agent_name}/history.md` の絶対パス
- `{report_save_path}`: `.agent_audit_reviewer2/{agent_name}/reports/round-{NNN}-comparison.md`
- `{selected_name}`: 選択されたプロンプト名
- `{selected_scoring_doc1_path}`: 選択プロンプトの文書1採点ファイル（現在ベスト維持なら空）
- `{selected_scoring_doc2_path}`: 選択プロンプトの文書2採点ファイル（現在ベスト維持なら空）
- `{round_number}`: 現在のラウンド番号

**B) proven-insights.md 更新** と **C) 次アクション選択** を同時に実行する:

**B)** `Task`（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_audit_reviewer2/templates/insights-extract.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{proven_insights_path}`: `.claude/skills/agent_audit_reviewer2/proven-insights.md` の絶対パス
- `{history_path}`: `.agent_audit_reviewer2/{agent_name}/history.md` の絶対パス
- `{report_save_path}`: `.agent_audit_reviewer2/{agent_name}/reports/round-{NNN}-comparison.md`
- `{agent_name}`: Phase 0 で決定した値

**C)** `AskUserQuestion` でユーザーに確認する:
- 選択肢:
  1. **次ラウンドへ** — 続けて最適化を実行する
  2. **終了** — 最適化を終了する
- 収束判定に該当する場合はその旨を付記する
- 累計ラウンド数が5以上の場合は「推奨ラウンド数に達しました」を付記する

B) の完了を待ってから:
- 「次ラウンド」: `{round_number}` を +1 して Phase 1 に戻る
- 「終了」: 以下の最終サマリを出力して完了

```
## agent_audit_reviewer2 最適化完了
- エージェント: {agent_name}
- ファイル: {agent_path}
- 総ラウンド数: {N}
- 最終プロンプト: {prompt_name}
- 最終スコア: Mean={X.XX}, SD={X.XX}, cross_doc_gap={X.XX}
- 初期からの改善: +{X.XX}pt ({+XX.X%})

## ラウンド別性能推移
| Round | Best | Score | SD | cross_doc_gap | Category Regressions |
|-------|------|-------|----|---------------|---------------------|
| R0    | ...  | ...   | ...| ...           | ...                 |
| ...   | ...  | ...   | ...| ...           | ...                 |
```
