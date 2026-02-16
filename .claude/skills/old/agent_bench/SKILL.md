---
allowed-tools: Glob, Grep, Read, Write, Edit, Task, AskUserQuestion
description: エージェント定義ファイルの構造バリアントを評価・比較し、性能向上の知見を蓄積するスキル
disable-model-invocation: true
---

エージェント定義ファイル（mdファイル）を新規作成または既存改善し、テストに対する性能を反復的に比較評価して最適化します。各ラウンドで得られた知見を `knowledge.md` に蓄積し、反復的に改善します。

## 使い方

```
/agent_bench <file_path>    # エージェント定義ファイルを指定して構造最適化
```

- `file_path`: エージェント定義ファイルのパス（必須）

全エージェントで perspective（評価観点定義）に基づく統一的な評価を行います。perspective が存在しない場合は自動生成します。

## コンテキスト節約の原則

1. **参照ファイルは使用するPhaseでのみ読み込む**（先読みしない）
2. **大量コンテンツの生成はサブエージェントに委譲する**
3. **サブエージェントからの返答は最小限にする**（詳細はファイルに保存させる）
4. **親コンテキストには要約・メタデータのみ保持する**
5. **サブエージェント間のデータ受け渡しはファイル経由で行う**（親を中継しない）

## ワークフロー

Phase 0 で perspective の解決と初回/継続を判定する。初回は Phase 1A、継続は Phase 1B に進む。Phase 2 で毎ラウンドのテスト入力文書を生成し、Phase 3 → 4 → 5 → 6 を順に実行する。

---

### Phase 0: 初期化・状態検出

#### エージェントファイルの読み込み

1. 引数から `agent_path` を取得する（未指定の場合は `AskUserQuestion` で確認）
2. Read で `agent_path` のファイルを読み込む。読み込み失敗時はエラー出力して終了

#### agent_name の導出

3. `{agent_name}` を以下のルールで導出する:
   - `agent_path` が `.claude/` 配下の場合: `.claude/` からの相対パスの拡張子を除いた部分
     - 例: `.claude/agents/security-design-reviewer.md` → `agents/security-design-reviewer`
   - それ以外の場合: プロジェクトルートからの相対パスの拡張子を除いた部分
     - 例: `my-agents/custom.md` → `my-agents/custom`

#### パースペクティブの解決

4. perspective ファイルを以下の順序で検索する:
   a. `.agent_bench/{agent_name}/perspective-source.md` を Read で確認する
   b. 見つからない場合、ファイル名（拡張子なし）が `{key}-{target}-reviewer` パターンに一致するか判定する:
      - `*-design-reviewer` → `{key}` = `-design-reviewer` の前の部分, `{target}` = `design`
      - `*-code-reviewer` → `{key}` = `-code-reviewer` の前の部分, `{target}` = `code`
      - 一致した場合: `.claude/skills/agent_bench/perspectives/{target}/{key}.md` を Read で確認する
      - 見つかった場合: `.agent_bench/{agent_name}/perspective-source.md` に Write でコピーする
   c. いずれも見つからない場合: パースペクティブ自動生成（後述）を実行する

5. perspective が見つかった場合（検索または自動生成で取得）:
   - `{perspective_source_path}` = `.agent_bench/{agent_name}/perspective-source.md` の絶対パス
   - perspective-source.md から「## 問題バンク」セクション以降を除いた内容を `.agent_bench/{agent_name}/perspective.md` に Write で保存する（作業コピー。Phase 4 採点バイアス防止のため問題バンクは含めない）

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
- `{perspective_save_path}`: `.agent_bench/{agent_name}/perspective-source.md` の絶対パス
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

#### 共通処理

6. `.agent_bench/{agent_name}/knowledge.md` を Read で読み込む
   - **読み込み成功** → Phase 1B へ
   - **読み込み失敗**（ファイル不在）→ knowledge.md を初期化して Phase 1A へ

#### knowledge.md の初期化（ファイル不在時のみ）

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_bench/templates/knowledge-init-template.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{knowledge_path}`: `.agent_bench/{agent_name}/knowledge.md` の絶対パス
- `{approach_catalog_path}`: `.claude/skills/agent_bench/approach-catalog.md` の絶対パス
- `{agent_name}`, `{agent_path}`: Phase 0 で決定した値
- `{perspective_source_path}`: `.agent_bench/{agent_name}/perspective-source.md` の絶対パス

テキスト出力:
```
## Phase 0: 初期化
- エージェント: {agent_name} ({agent_path})
- パースペクティブ: {既存 / 自動生成}
- knowledge.md: {あり ({累計ラウンド数} ラウンド) / 新規初期化}
- 次フェーズ: {Phase 1A / Phase 1B}
```

---

### Phase 1A: 初回 — ベースライン作成 + バリアント生成（サブエージェントに委譲）

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_bench/templates/phase1a-variant-generation.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{agent_path}`: エージェント定義ファイルの絶対パス（存在しない場合は「新規」と指定）
- `{prompts_dir}`: `.agent_bench/{agent_name}/prompts` の絶対パス
- `{approach_catalog_path}`: `.claude/skills/agent_bench/approach-catalog.md` の絶対パス
- `{proven_techniques_path}`: `.claude/skills/agent_bench/proven-techniques.md` の絶対パス
- `{perspective_source_path}`: `.agent_bench/{agent_name}/perspective-source.md` の絶対パス
- `{perspective_path}`: `.agent_bench/{agent_name}/perspective.md` の絶対パス
- `{agent_name}`: Phase 0 で決定した値
- エージェント定義が新規作成の場合:
  - `{user_requirements}`: Phase 0 で収集した要件テキスト

サブエージェントの返答をテキスト出力し、Phase 2 へ進む。

---

### Phase 1B: 継続 — 知見ベースのバリアント生成

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_bench/templates/phase1b-variant-generation.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{knowledge_path}`: `.agent_bench/{agent_name}/knowledge.md` の絶対パス
- `{agent_path}`: エージェント定義ファイルの絶対パス
- `{prompts_dir}`: `.agent_bench/{agent_name}/prompts` の絶対パス
- `{approach_catalog_path}`: `.claude/skills/agent_bench/approach-catalog.md` の絶対パス
- `{proven_techniques_path}`: `.claude/skills/agent_bench/proven-techniques.md` の絶対パス
- `{perspective_path}`: `.agent_bench/{agent_name}/perspective.md` の絶対パス
- Glob で `.agent_audit/{agent_name}/audit-*.md` を検索し（`audit-approved.md` は除外）、見つかった全ファイルのパスをカンマ区切りで `{audit_findings_paths}` として渡す

サブエージェントの返答をテキスト出力し、次の Phase へ進む。

---

### Phase 2: テスト入力文書生成（毎ラウンド実行）

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_bench/templates/phase2-test-document.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{test_document_guide_path}`: `.claude/skills/agent_bench/test-document-guide.md` の絶対パス
- `{perspective_path}`: `.agent_bench/{agent_name}/perspective.md` の絶対パス
- `{perspective_source_path}`: `.agent_bench/{agent_name}/perspective-source.md` の絶対パス（問題バンクを含む）
- `{knowledge_path}`: `.agent_bench/{agent_name}/knowledge.md` の絶対パス
- `{test_document_save_path}`: `.agent_bench/{agent_name}/test-document-round-{NNN}.md` の絶対パス（NNN = 累計ラウンド数 + 1）
- `{answer_key_save_path}`: `.agent_bench/{agent_name}/answer-key-round-{NNN}.md` の絶対パス

サブエージェントの返答をテキスト出力し、Phase 3 へ進む。

---

### Phase 3: 並列評価実行

Phase 3 開始時に以下をテキスト出力する:

```
## Phase 3: 並列評価実行
- 評価タスク数: {N}（{プロンプト数} × 2回）
- 実行プロンプト: {プロンプト名リスト}
```

各プロンプトを2回ずつ `Task` ツールで並列実行する（全て同一メッセージ内で起動）:
- 並列数 = (ベースライン1 + バリアント数) × 2回
- `subagent_type: "general-purpose"`, `model: "sonnet"`

各サブエージェントへの指示:

```
以下の手順でタスクを実行してください:

1. Read で {prompt_path} を読み込み、その内容に従ってタスクを実行してください
2. Read で {test_doc_path} を読み込み、処理対象としてください
3. 処理結果を Write で {result_path} に保存してください
4. 最後に「保存完了: {result_path}」とだけ返答してください
```

- `{prompt_path}`: 評価対象プロンプトの絶対パス
- `{test_doc_path}`: `.agent_bench/{agent_name}/test-document-round-{NNN}.md`
- `{result_path}`: `.agent_bench/{agent_name}/results/v{NNN}-{name}-run{R}.md`
- `{NNN}`: プロンプトのバージョン番号
- `{name}`: プロンプトの名前部分
- `{R}`: 実行回数（1 または 2）

全サブエージェント完了後、成功数を集計し分岐する:

- **成功数 = 総数**: Phase 4 へ進む
- **成功数 < 総数 かつ、各プロンプトに最低1回の成功結果がある**: 警告を出力し Phase 4 へ進む（採点は成功した Run のみで実施。Run が1回のみのプロンプトは SD = N/A とする）
- **いずれかのプロンプトで成功結果が0回**: `AskUserQuestion` で確認する
  - **再試行**: 失敗したタスクのみ再実行する（1回のみ）
  - **該当プロンプトを除外して続行**: 成功結果があるプロンプトのみで Phase 4 へ進む
  - **中断**: エラー内容を出力してスキルを終了する

テキスト出力:
```
評価完了: {成功数}/{総数} タスク成功。Phase 4（採点）に進みます。
```

---

### Phase 4: 採点（サブエージェントの並列実行）

プロンプトごとに1つの採点サブエージェントを `Task` で並列起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

各サブエージェントへの指示: `.claude/skills/agent_bench/templates/phase4-scoring.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{scoring_rubric_path}`: `.claude/skills/agent_bench/scoring-rubric.md` の絶対パス
- `{scoring_save_path}`: `.agent_bench/{agent_name}/results/v{NNN}-{name}-scoring.md`
- `{prompt_name}`: 評価対象プロンプトの名前
- `{answer_key_path}`: `.agent_bench/{agent_name}/answer-key-round-{NNN}.md` の絶対パス
- `{perspective_path}`: `.agent_bench/{agent_name}/perspective.md` の絶対パス
- `{result_run1_path}`, `{result_run2_path}`: 各プロンプトの Run1/Run2 結果ファイルの絶対パス

全採点サブエージェントの完了を待ち、成功数を集計する:

- **全て成功**: 各サブエージェントの返答（スコアサマリ）をテキスト出力し、Phase 5 へ進む
- **一部失敗**: `AskUserQuestion` で確認する
  - **再試行**: 失敗した採点タスクのみ再実行する（1回のみ）
  - **失敗プロンプトを除外して続行**: 成功したプロンプトのみで Phase 5 へ進む（ベースラインが失敗した場合は中断）
  - **中断**: エラー内容を出力してスキルを終了する

---

### Phase 5: 分析・推奨判定・レポート作成（サブエージェントに委譲）

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_bench/templates/phase5-analysis-report.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{scoring_rubric_path}`: `.claude/skills/agent_bench/scoring-rubric.md` の絶対パス
- `{knowledge_path}`: `.agent_bench/{agent_name}/knowledge.md` の絶対パス
- `{scoring_file_paths}`: Phase 4 で保存された採点ファイルのパス一覧
- `{report_save_path}`: `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md`

サブエージェント完了後、サブエージェントの返答（7行サマリ）をテキスト出力してユーザーに提示する。Phase 6 へ進む。

---

### Phase 6: プロンプト選択・デプロイ・次アクション（親で実行）

#### ステップ1: プロンプト選択とデプロイ

`.agent_bench/{agent_name}/knowledge.md` を Read で読み込み、「ラウンド別スコア推移」セクションから過去ラウンドのスコアデータを取得する。Phase 5 のサブエージェント返答（7行サマリ）と合わせて、`AskUserQuestion` でユーザーに提示する:

- **ラウンド別性能推移テーブル**:
```
## 性能推移
| Round | Baseline | Variant 1 | Variant 2 | Best | Δ from Initial |
|-------|----------|-----------|-----------|------|----------------|
| R1    | 6.2(0.3) | 7.1(0.4) | 6.8(0.2) | 7.1  | +0.9           |
| ...   | ...      | ...       | ...       | ...  | ...            |

初期スコア: {初期値} → 現在ベスト: {現在値} (改善: +{差分}pt, +{改善率}%)
全ラウンド最高スコア: {全ラウンドのBestの最大値} (Round {N}, {prompt_name})
```
- 推奨プロンプトとその推奨理由
- 収束判定（該当する場合は「最適化が収束した可能性あり」を付記）

選択肢: 評価した全プロンプト名（ベースライン含む）を列挙。推奨プロンプトの選択肢に「(推奨)」を付記。

ユーザーの選択に応じて:
- **ベースライン以外を選択した場合**: `Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "haiku"`）:
  ```
  以下の手順でプロンプトをデプロイしてください:
  1. Read で {selected_prompt_path} を読み込む
  2. ファイル先頭の <!-- Benchmark Metadata ... --> ブロックを除去する
  3. {agent_path} に Write で上書き保存する
  4. 「デプロイ完了: {agent_path}」とだけ返答する
  ```
- **ベースラインを選択した場合**: 変更なし

#### ステップ2: ナレッジ更新・スキル知見フィードバック・次アクション選択

**まず** ナレッジ更新を実行し完了を待つ:

**A) ナレッジ更新サブエージェント**

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_bench/templates/phase6a-knowledge-update.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{knowledge_path}`: `.agent_bench/{agent_name}/knowledge.md` の絶対パス
- `{report_save_path}`: `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md`
- `{recommended_name}`, `{judgment_reason}`: Phase 5 のサブエージェント返答の recommended と reason

**次に** 以下の2つを同時に実行する:

**B) スキル知見フィードバックサブエージェント**

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_bench/templates/phase6b-proven-techniques-update.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{proven_techniques_path}`: `.claude/skills/agent_bench/proven-techniques.md` の絶対パス
- `{knowledge_path}`: `.agent_bench/{agent_name}/knowledge.md` の絶対パス
- `{report_save_path}`: `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md`
- `{agent_name}`: Phase 0 で決定した値

**C) 次アクション選択（親で実行）**

`AskUserQuestion` でユーザーに確認する:
- 選択肢:
  1. **次ラウンドへ** — 続けて最適化を実行する
  2. **終了** — 最適化を終了する
- 収束判定が「収束の可能性あり」の場合はその旨を付記する
- 累計ラウンド数が3以上の場合は「目標ラウンド数に達しました」を付記する

B) スキル知見フィードバックサブエージェントの完了を待ってから:
- 「次ラウンド」の場合: Phase 1B に戻る
- 「終了」の場合: 以下の最終サマリを出力してスキル完了

```
## agent_bench 最適化完了
- エージェント: {agent_name}
- ファイル: {agent_path}
- 総ラウンド数: {N}
- 最終プロンプト: {prompt_name}
- 最終スコア: Mean={X.XX}, SD={X.XX}
- 初期からの改善: +{X.XX}pt ({+XX.X%})
- 効果のあったテクニック: {knowledge.md の上位項目}

## ラウンド別性能推移
| Round | Best Score | Δ from Initial | Applied Technique | Result |
|-------|-----------|----------------|-------------------|--------|
| R1    | {score}   | {delta}        | {technique}       | {EFFECTIVE/INEFFECTIVE} |
| ...   | ...       | ...            | ...               | ...    |
```
