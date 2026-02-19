---
allowed-tools: Glob, Grep, Read, Write, Edit, Task, AskUserQuestion
description: OPRO式エラー駆動アプローチでレビュー系エージェント定義を反復最適化するスキル
disable-model-invocation: true
---

レビュー系エージェント定義ファイル（mdファイル）のプロンプトを、OPRO式エラー駆動ループで反復最適化します。固定テスト文書に対する検出性能を評価し、エラー分析に基づいてLLMが自由に改善バリアントを生成します。各ラウンドで得られた知見を `history.md` に蓄積し、エージェント横断の知見を `proven-insights.md` に集約します。

## 使い方

```
/agent_audit_reviewer <file_path>    # レビュー系エージェント定義ファイルを指定して最適化
```

- `file_path`: レビュー系エージェント定義ファイルのパス（必須。`*-reviewer` パターン）

## コンテキスト節約の原則

1. **参照ファイルは使用するPhaseでのみ読み込む**（先読みしない）
2. **大量コンテンツの生成はサブエージェントに委譲する**
3. **サブエージェントからの返答は最小限にする**（詳細はファイルに保存させる）
4. **親コンテキストには要約・メタデータのみ保持する**
5. **サブエージェント間のデータ受け渡しはファイル経由で行う**（親を中継しない）

## ワークフロー

Phase 0 で固定テスト文書を生成しベースラインを評価する。Phase 1（メタインプルーバー）→ Phase 2（評価）→ Phase 3（採点+分析）→ Phase 4（選択+更新）を繰り返す。

---

### Phase 0: 初期化・ベースライン評価

#### エージェントファイルの読み込み

1. 引数から `agent_path` を取得する（未指定の場合は `AskUserQuestion` で確認）
2. Read で `agent_path` のファイルを読み込む。読み込み失敗時はエラー出力して終了

#### agent_name の導出

3. `{agent_name}` を以下のルールで導出する:
   - `agent_path` が `.claude/` 配下の場合: `.claude/` からの相対パスの拡張子を除いた部分
     - 例: `.claude/agents/security-design-reviewer.md` → `agents/security-design-reviewer`
   - それ以外の場合: プロジェクトルートからの相対パスの拡張子を除いた部分

#### パースペクティブの解決

4. perspective ファイルを以下の順序で検索する:
   a. `.agent_audit_reviewer/{agent_name}/perspective-source.md` を Read で確認する
   b. 見つからない場合、ファイル名（拡張子なし）が `{key}-{target}-reviewer` パターンに一致するか判定する:
      - `*-design-reviewer` → `{key}` = `-design-reviewer` の前の部分, `{target}` = `design`
      - `*-code-reviewer` → `{key}` = `-code-reviewer` の前の部分, `{target}` = `code`
      - 一致した場合: `.claude/skills/agent_bench/perspectives/{target}/{key}.md` を Read で確認する
      - 見つかった場合: `.agent_audit_reviewer/{agent_name}/perspective-source.md` に Write でコピーする
   c. いずれも見つからない場合: パースペクティブ自動生成（後述）を実行する

5. perspective が見つかった場合（検索または自動生成で取得）:
   - `{perspective_source_path}` = `.agent_audit_reviewer/{agent_name}/perspective-source.md` の絶対パス
   - perspective-source.md から「## 問題バンク」セクション以降を除いた内容を `.agent_audit_reviewer/{agent_name}/perspective.md` に Write で保存する（作業コピー。Phase 3 採点バイアス防止のため問題バンクは含めない）

#### パースペクティブ自動生成（perspective 未検出の場合）

テンプレートを使って perspective を自動生成する:

**Step 1: 要件抽出**
- エージェント定義ファイルの内容（目的、評価基準、入力/出力の型、スコープ情報）を `{user_requirements}` として構成する
- エージェント定義が実質空または不足がある場合: `AskUserQuestion` で以下をヒアリングし `{user_requirements}` に追加する
  - エージェントの目的・役割
  - 想定される入力と期待される出力
  - 使用ツール・制約事項

**Step 2: 既存 perspective の参照データ収集**
- `.claude/skills/agent_bench/perspectives/design/*.md` を Glob で列挙する
- 最初に見つかったファイルを `{reference_perspective_path}` として使用する（構造とフォーマットの参考用）
- 見つからない場合は `{reference_perspective_path}` を空とする

**Step 3: perspective 初期生成**
`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_bench/templates/perspective/generate-perspective.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{agent_path}`: エージェント定義ファイルの絶対パス
- `{user_requirements}`: Step 1 で構成したテキスト
- `{perspective_save_path}`: `.agent_audit_reviewer/{agent_name}/perspective-source.md` の絶対パス
- `{reference_perspective_path}`: Step 2 で取得したパス

**Step 4: 批判レビュー（4並列）**
以下の4つの `Task` を同一メッセージ内で並列起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

各エージェントへのプロンプト:
`.claude/skills/agent_bench/templates/perspective/{テンプレート名}` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{perspective_path}`: Step 3 で保存した perspective ファイルの絶対パス
- `{agent_path}`: エージェント定義ファイルの絶対パス

| テンプレート | 焦点 |
|-------------|------|
| `critic-effectiveness.md` | 品質寄与度 + 他観点との境界 |
| `critic-completeness.md` | 網羅性 + 未考慮事項検出 + 問題バンク |
| `critic-clarity.md` | 表現明確性 + AI動作一貫性 |
| `critic-generality.md` | 汎用性 + 業界依存性フィルタ |

**Step 5: フィードバック統合・再生成**
- 4件の批評から「重大な問題」「改善提案」を分類する
- 重大な問題または改善提案がある場合: フィードバックを `{user_requirements}` に追記し、Step 3 と同じパターンで perspective を再生成する（1回のみ）
- 改善不要の場合: 現行 perspective を維持する

**Step 6: 検証**
- 生成された perspective を Read し、必須セクション（`## 概要`, `## 評価スコープ`, `## スコープ外`, `## ボーナス/ペナルティの判定指針`, `## 問題バンク`）の存在を確認する
- 検証成功 → perspective 解決完了
- 検証失敗 → エラー出力してスキルを終了する

#### 状態検出

6. `.agent_audit_reviewer/{agent_name}/history.md` を Read で読み込む
   - **読み込み成功** → 継続モード。history.md の「Agent Info」セクションから `{current_round}` を取得し、`{round_number}` = `{current_round}` + 1 として Phase 1 へ
   - **読み込み失敗**（ファイル不在）→ 初回モード。Step 7 以降を実行する

#### 固定テスト文書生成（初回のみ）

7. `Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_audit_reviewer/templates/init-test-document.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{test_document_guide_path}`: `.claude/skills/agent_bench/test-document-guide.md` の絶対パス
- `{perspective_path}`: `.agent_audit_reviewer/{agent_name}/perspective.md` の絶対パス
- `{perspective_source_path}`: `.agent_audit_reviewer/{agent_name}/perspective-source.md` の絶対パス
- `{test_document_save_path}`: `.agent_audit_reviewer/{agent_name}/test-document.md` の絶対パス
- `{answer_key_save_path}`: `.agent_audit_reviewer/{agent_name}/answer-key.md` の絶対パス

#### テスト文書の品質検証（初回のみ）

7.5. `Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_audit_reviewer/templates/validate-test-document.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{test_document_path}`: `.agent_audit_reviewer/{agent_name}/test-document.md` の絶対パス
- `{answer_key_path}`: `.agent_audit_reviewer/{agent_name}/answer-key.md` の絶対パス
- `{perspective_path}`: `.agent_audit_reviewer/{agent_name}/perspective.md` の絶対パス

サブエージェントの返答の「総合判定」を確認する:
- **PASS**: Step 8 へ進む
- **FAIL**: 問題詳細を `{user_requirements}` に追記し、Step 7 のテスト文書生成を再実行する（1回のみ）。再検証でも FAIL の場合はエラー出力してスキルを終了する

#### ベースラインコピーと評価（初回のみ）

8. エージェント定義ファイルを Read し、先頭に Benchmark Metadata コメントを付与して `.agent_audit_reviewer/{agent_name}/prompts/v001-baseline.md` に Write で保存する

9. v001-baseline を3回並列で評価する。3つの `Task` を同一メッセージ内で起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

各サブエージェントへの指示:
```
以下の手順でタスクを実行してください:
1. Read で {prompt_path} を読み込み、その内容に従ってタスクを実行してください
2. Read で {test_doc_path} を読み込み、処理対象としてください
3. 処理結果を Write で {result_path} に保存してください
4. 最後に「保存完了: {result_path}」とだけ返答してください
```
- `{prompt_path}`: `.agent_audit_reviewer/{agent_name}/prompts/v001-baseline.md`
- `{test_doc_path}`: `.agent_audit_reviewer/{agent_name}/test-document.md`
- `{result_path}`: `.agent_audit_reviewer/{agent_name}/results/v001-baseline-run1.md`, `v001-baseline-run2.md`, `v001-baseline-run3.md`

10. ベースライン採点を実行する。`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_audit_reviewer/templates/scoring-with-analysis.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{scoring_rubric_path}`: `.claude/skills/agent_audit_reviewer/scoring-rubric.md` の絶対パス
- `{answer_key_path}`: `.agent_audit_reviewer/{agent_name}/answer-key.md` の絶対パス
- `{perspective_path}`: `.agent_audit_reviewer/{agent_name}/perspective.md` の絶対パス
- `{result_run1_path}`: `.agent_audit_reviewer/{agent_name}/results/v001-baseline-run1.md` の絶対パス
- `{result_run2_path}`: `.agent_audit_reviewer/{agent_name}/results/v001-baseline-run2.md` の絶対パス
- `{result_run3_path}`: `.agent_audit_reviewer/{agent_name}/results/v001-baseline-run3.md` の絶対パス
- `{prompt_name}`: v001-baseline
- `{scoring_save_path}`: `.agent_audit_reviewer/{agent_name}/results/v001-baseline-scoring.md` の絶対パス

#### history.md の初期化（初回のみ）

11. ベースライン採点ファイル `.agent_audit_reviewer/{agent_name}/results/v001-baseline-scoring.md` を Read し、「エラー分析」セクションと「検出マトリクス」セクションを抽出する。テスト文書生成サブエージェントの返答からテーマ情報を取得する。

正解キー `.agent_audit_reviewer/{agent_name}/answer-key.md` を Read し、各問題の深刻度・検出難易度を取得する。

検出マトリクスの Run1/Run2/Run3 結果から各問題の識別力を以下のルールで判定する:
- **天井（常時検出）**: 3Run全て ○ → 識別力「低」
- **床（常時未検出）**: 3Run全て × → 識別力「低」
- **安定検出**: 3Run中2回以上 ○、残りが △ → 識別力「中」
- **変動あり**: Run間で ○/△/× の組み合わせが混在 → 識別力「高」
- **安定未検出**: 3Run中2回以上 ×、残りが △ → 識別力「中」

以下のフォーマットで history.md を Write する:

```markdown
# Optimization History: {agent_name}

## Agent Info
- Path: {agent_path}
- Test Document: {theme} ({line_count} lines)
- Initial Score: {baseline_mean} (SD={baseline_sd})
- Current Best: v001-baseline ({baseline_mean})
- Rounds: 0

## Item Analysis
| ID | Category | Severity | Detection Difficulty | Run1 | Run2 | Run3 | Discrimination |
|----|----------|----------|---------------------|------|------|------|---------------|
| P01 | {cat} | {sev} | {diff} | {○/△/×} | {○/△/×} | {○/△/×} | {低/中/高} |
...

Summary: 識別力高={N}問, 識別力中={N}問, 識別力低（天井）={N}問, 識別力低（床）={N}問

## Current Error Analysis

{採点ファイルのエラー分析セクションをここに転記}

## Round History
| Round | Best | Score | SD | Key Change | Remaining Errors |
|-------|------|-------|----|------------|-----------------|
| R0 | v001-baseline | {mean} | {sd} | (initial) | {missed+partial count} categories |

## Effective Changes
| Change | Effect (pt) | SD | Round | Target Category |
|--------|-------------|-----|-------|----------------|

## Ineffective Changes
| Change | Effect (pt) | SD | Round | Target Category |
|--------|-------------|-----|-------|----------------|
```

`{round_number}` = 1 に設定する。

テキスト出力:
```
## Phase 0: 初期化
- エージェント: {agent_name} ({agent_path})
- パースペクティブ: {既存 / 自動生成}
- テスト文書: {行数}行, テーマ: {テーマ}
- ベースラインスコア: Mean={X.X}, SD={X.X}
- 次フェーズ: Phase 1 (Round 1)
```

---

### Phase 1: Improve（メタインプルーバー）

現在のベストプロンプトのパスを決定する:
- Round 1: `{agent_path}`（元のエージェント定義ファイル）
- Round 2+: history.md の「Current Best」からプロンプトファイル名を取得し、`.agent_audit_reviewer/{agent_name}/prompts/` 配下の絶対パスに解決する

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_audit_reviewer/templates/meta-improver.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{current_best_path}`: 現在のベストプロンプトの絶対パス
- `{history_path}`: `.agent_audit_reviewer/{agent_name}/history.md` の絶対パス
- `{proven_insights_path}`: `.claude/skills/agent_audit_reviewer/proven-insights.md` の絶対パス
- `{proven_techniques_path}`: `.claude/skills/agent_bench/proven-techniques.md` の絶対パス
- `{perspective_path}`: `.agent_audit_reviewer/{agent_name}/perspective.md` の絶対パス
- `{prompts_dir}`: `.agent_audit_reviewer/{agent_name}/prompts` の絶対パス
- `{round_number}`: 現在のラウンド番号

サブエージェントの返答から `variant_count`（`## 生成したバリアント` セクションの `variant_count:` 行）とバリアントファイル名リストを抽出する。返答をテキスト出力し、Phase 2 へ進む。

---

### Phase 2: 並列評価実行

Phase 2 開始時に以下をテキスト出力する:
```
## Phase 2: 並列評価実行 (Round {round_number})
- 評価タスク数: {variant_count × 3}（{variant_count}バリアント × 3回）
- 実行プロンプト: {バリアント名リスト}
```

生成されたバリアントを各3回、合計 {variant_count × 3} 個の `Task` を同一メッセージ内で並列起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

各サブエージェントへの指示:
```
以下の手順でタスクを実行してください:
1. Read で {prompt_path} を読み込み、その内容に従ってタスクを実行してください
2. Read で {test_doc_path} を読み込み、処理対象としてください
3. 処理結果を Write で {result_path} に保存してください
4. 最後に「保存完了: {result_path}」とだけ返答してください
```
- `{prompt_path}`: `.agent_audit_reviewer/{agent_name}/prompts/v{NNN}-variant-{name}.md`（NNN = round_number + 1）
- `{test_doc_path}`: `.agent_audit_reviewer/{agent_name}/test-document.md`
- `{result_path}`: `.agent_audit_reviewer/{agent_name}/results/v{NNN}-{name}-run{R}.md`（R = 1, 2, 3）

全サブエージェント完了後、成功数を集計し分岐する:
- **全タスク成功**: Phase 3 へ進む
- **一部失敗だが各バリアントに最低2回の成功結果がある**: 警告を出力し Phase 3 へ進む
- **いずれかのバリアントで成功結果が1回以下**: `AskUserQuestion` で確認する
  - **再試行**: 失敗したタスクのみ再実行する（1回のみ）
  - **該当バリアントを除外して続行**
  - **中断**: エラー内容を出力してスキルを終了する

---

### Phase 3: 採点 + 分析

#### Step 3.1: バリアント採点（並列実行）

バリアントごとに1つの採点サブエージェントを `Task` で並列起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

各サブエージェントへの指示: `.claude/skills/agent_audit_reviewer/templates/scoring-with-analysis.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{scoring_rubric_path}`: `.claude/skills/agent_audit_reviewer/scoring-rubric.md` の絶対パス
- `{answer_key_path}`: `.agent_audit_reviewer/{agent_name}/answer-key.md` の絶対パス
- `{perspective_path}`: `.agent_audit_reviewer/{agent_name}/perspective.md` の絶対パス
- `{result_run1_path}`, `{result_run2_path}`, `{result_run3_path}`: 各バリアントの Run1/Run2/Run3 結果ファイルの絶対パス
- `{prompt_name}`: バリアント名
- `{scoring_save_path}`: `.agent_audit_reviewer/{agent_name}/results/v{NNN}-{name}-scoring.md`

#### Step 3.2: 比較レポート生成

全採点完了後、`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_audit_reviewer/templates/analysis-report.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{scoring_rubric_path}`: `.claude/skills/agent_audit_reviewer/scoring-rubric.md` の絶対パス
- `{history_path}`: `.agent_audit_reviewer/{agent_name}/history.md` の絶対パス
- `{scoring_file_paths}`: 今回の全バリアント（{variant_count}個）の採点ファイルパス
- `{prompt_file_paths}`: 今回の全バリアントのプロンプトファイルパス（Benchmark Metadata 読み取り用）
- `{report_save_path}`: `.agent_audit_reviewer/{agent_name}/reports/round-{NNN}-comparison.md`（NNN = round_number + 1）

サブエージェント完了後、サブエージェントの返答（バリアント別分析+推奨）をテキスト出力してユーザーに提示する。Phase 4 へ進む。

---

### Phase 4: プロンプト選択・更新・次アクション

#### ステップ1: プロンプト選択とデプロイ

`.agent_audit_reviewer/{agent_name}/history.md` を Read で読み込み、「Round History」セクションから過去ラウンドのスコアデータを取得する。

`AskUserQuestion` でユーザーに提示する:

```
## 性能推移
| Round | Best Prompt | Score | SD | Key Change | Remaining Errors |
|-------|-------------|-------|----|------------|-----------------|
| R0    | baseline    | {X.X} | {X.X} | (initial) | {N} categories |
| ...   | ...         | ...   | ...   | ...        | ...             |

初期スコア: {初期値} → 現在ベスト: {現在値} (改善: +{差分}pt, +{改善率}%)
```
- 収束判定（該当する場合は「最適化が収束した可能性あり」を付記）

注: バリアント別の変更点・期待効果・結果解釈・リスク評価は Phase 3.2 で既にテキスト出力済み。

選択肢: 現在のベスト + 評価した全バリアント名を列挙。推奨プロンプトの選択肢に「(推奨)」を付記。

ユーザーの選択に応じて:
- **バリアントを選択した場合**: `Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "haiku"`）:
  ```
  以下の手順でプロンプトをデプロイしてください:
  1. Read で {selected_prompt_path} を読み込む
  2. ファイル先頭の <!-- Benchmark Metadata ... --> ブロックを除去する
  3. {agent_path} に Write で上書き保存する
  4. 「デプロイ完了: {agent_path}」とだけ返答する
  ```
- **現在のベストを選択した場合**: 変更なし

#### ステップ1.5: Validation Check（オプション）

バリアントを選択してデプロイした場合のみ、`AskUserQuestion` で確認する:
- 「Validation check を実行しますか？（別ドメインのテスト文書で汎化性能を検証）」
- 選択肢: **スキップ（推奨）** / **実行する**

**実行する場合:**

a. `Task` ツールで validation テスト文書を生成する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_audit_reviewer/templates/init-test-document.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{test_document_guide_path}`: `.claude/skills/agent_bench/test-document-guide.md` の絶対パス
- `{perspective_path}`: `.agent_audit_reviewer/{agent_name}/perspective.md` の絶対パス
- `{perspective_source_path}`: `.agent_audit_reviewer/{agent_name}/perspective-source.md` の絶対パス
- `{test_document_save_path}`: `.agent_audit_reviewer/{agent_name}/validation-test-document.md` の絶対パス
- `{answer_key_save_path}`: `.agent_audit_reviewer/{agent_name}/validation-answer-key.md` の絶対パス

追加指示: 固定テスト文書 `.agent_audit_reviewer/{agent_name}/test-document.md` とは**異なるドメイン**を選択すること。

b. 選択されたプロンプトで validation テスト文書を1回評価する。`Task` を起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:
```
以下の手順でタスクを実行してください:
1. Read で {prompt_path} を読み込み、その内容に従ってタスクを実行してください
2. Read で {test_doc_path} を読み込み、処理対象としてください
3. 処理結果を Write で {result_path} に保存してください
4. 最後に「保存完了: {result_path}」とだけ返答してください
```
- `{prompt_path}`: デプロイしたプロンプトファイルのパス
- `{test_doc_path}`: `.agent_audit_reviewer/{agent_name}/validation-test-document.md`
- `{result_path}`: `.agent_audit_reviewer/{agent_name}/results/validation-run1.md`

c. validation 採点を実行する。`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_audit_reviewer/templates/scoring-with-analysis.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{scoring_rubric_path}`: `.claude/skills/agent_audit_reviewer/scoring-rubric.md` の絶対パス
- `{answer_key_path}`: `.agent_audit_reviewer/{agent_name}/validation-answer-key.md` の絶対パス
- `{perspective_path}`: `.agent_audit_reviewer/{agent_name}/perspective.md` の絶対パス
- `{result_run1_path}`: `.agent_audit_reviewer/{agent_name}/results/validation-run1.md` の絶対パス
- `{result_run2_path}`: 空（1回のみの評価）
- `{result_run3_path}`: 空（1回のみの評価）
- `{prompt_name}`: validation
- `{scoring_save_path}`: `.agent_audit_reviewer/{agent_name}/results/validation-scoring.md`

d. 結果をテキスト出力する:
```
## Validation Check
- Train score (固定テスト): Mean={X.X}
- Validation score (別ドメイン): {X.X}
- 乖離: {差分}pt ({乖離率}%)
- 判定: {OK（乖離率30%未満）/ 警告: 過学習の可能性あり（乖離率30%以上）}
```

#### ステップ2: ナレッジ更新・知見フィードバック・次アクション選択

**まず** ナレッジ更新を実行し完了を待つ:

**A) history.md 更新サブエージェント**

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_audit_reviewer/templates/history-update.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{history_path}`: `.agent_audit_reviewer/{agent_name}/history.md` の絶対パス
- `{report_save_path}`: `.agent_audit_reviewer/{agent_name}/reports/round-{NNN}-comparison.md`
- `{selected_name}`: ユーザーが選択したプロンプト名
- `{selected_scoring_path}`: 選択されたプロンプトの採点ファイルの絶対パス（現在ベスト維持の場合は空文字列）
- `{round_number}`: 現在のラウンド番号

**次に** 以下の2つを同時に実行する:

**B) proven-insights.md 更新サブエージェント**

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_audit_reviewer/templates/insights-extract.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{proven_insights_path}`: `.claude/skills/agent_audit_reviewer/proven-insights.md` の絶対パス
- `{proven_techniques_path}`: `.claude/skills/agent_bench/proven-techniques.md` の絶対パス
- `{history_path}`: `.agent_audit_reviewer/{agent_name}/history.md` の絶対パス
- `{report_save_path}`: `.agent_audit_reviewer/{agent_name}/reports/round-{NNN}-comparison.md`
- `{agent_name}`: Phase 0 で決定した値

**C) 次アクション選択（親で実行）**

`AskUserQuestion` でユーザーに確認する:
- 選択肢:
  1. **次ラウンドへ** — 続けて最適化を実行する
  2. **終了** — 最適化を終了する
- 収束判定が「収束の可能性あり」の場合はその旨を付記する
- 累計ラウンド数が5以上の場合は「推奨ラウンド数に達しました」を付記する

B) proven-insights 更新サブエージェントの完了を待ってから:
- 「次ラウンド」の場合: `{round_number}` を +1 して Phase 1 に戻る
- 「終了」の場合: 以下の最終サマリを出力してスキル完了

```
## agent_audit_reviewer 最適化完了
- エージェント: {agent_name}
- ファイル: {agent_path}
- 総ラウンド数: {N}
- 最終プロンプト: {prompt_name}
- 最終スコア: Mean={X.XX}, SD={X.XX}
- 初期からの改善: +{X.XX}pt ({+XX.X%})

## ラウンド別性能推移
| Round | Best Prompt | Score | SD | Key Change | Remaining Errors |
|-------|-------------|-------|----|------------|-----------------|
| R0    | ...         | ...   | ...| ...        | ...              |
| ...   | ...         | ...   | ...| ...        | ...              |
```
