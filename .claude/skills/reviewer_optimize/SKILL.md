---
allowed-tools: Glob, Grep, Read, Write, Edit, Task, AskUserQuestion
description: 指定された観点のレビューエージェント用プロンプトを反復的に生成・評価・改善し、性能向上の知見を蓄積するスキル
---

指定された観点（セキュリティ、パフォーマンス等）とレビュー対象（設計書、実装コード）の組み合わせに対して、レビューエージェント用プロンプトを複数生成し、テスト対象文書への検出性能を比較評価します。各ラウンドで得られた知見を `knowledge.md` に蓄積し、反復的にプロンプトを改善します。

## 使い方

```
/reviewer_optimize <perspective> <target>
```

- `perspective`: レビュー観点（security, performance, consistency, best-practices, maintainability 等）
- `target`: レビュー対象（design = 設計書, code = 実装コード）

いずれかが未指定の場合は `AskUserQuestion` で確認してください。

## コンテキスト節約の原則

1. **参照ファイルは使用するPhaseでのみ読み込む**（先読みしない）
2. **大量コンテンツの生成はサブエージェントに委譲する**
3. **サブエージェントからの返答は最小限にする**（詳細はファイルに保存させる）
4. **親コンテキストには要約・メタデータのみ保持する**
5. **サブエージェント間のデータ受け渡しはファイル経由で行う**（親を中継しない）

## ワークフロー

Phase 0 で初回/2回目以降を判定し、初回は Phase 1A、2回目以降は Phase 1B に進みます。その後 Phase 2 → 3 → 4 → 5 → 6 を順に実行します。

---

### Phase 0: 初期化・状態検出

1. 引数から `perspective` と `target` を取得する（未指定の場合は `AskUserQuestion` で確認）
2. エージェント定義ファイルのパスを決定する:
   - target が design の場合: `.claude/agents/{perspective}-design-reviewer.md`
   - target が code の場合: `.claude/agents/{perspective}-code-reviewer.md`
3. パースペクティブファイルの存在を確認する:
   - `.claude/skills/reviewer_optimize/perspectives/{target}/{perspective}.md` を Read で確認する
   - 存在しない場合: 「パースペクティブファイルが見つかりません: perspectives/{target}/{perspective}.md。このファイルを手動で作成するか、/reviewer_create {perspective} {target} を実行してください」とテキスト出力し、スキルを終了する
4. パースペクティブを作業ディレクトリにコピーする:
   - ソース: `.claude/skills/reviewer_optimize/perspectives/{target}/{perspective}.md`
   - 宛先: `prompt-improve/{perspective}-{target}/perspective.md`
   - ソースから「## 問題バンク」セクション以降を除いた内容を Write で保存する
     （問題バンクは Phase 2 がソースから直接参照する。Phase 4 採点バイアス防止のため作業コピーには含めない）
5. 実行モードを `AskUserQuestion` で確認する:
   - **標準モード**: 各Phase で中間確認を行う
   - **高速モード**: 中間確認をスキップし、デプロイ判定と次アクション選択のみ確認する
6. `prompt-improve/{perspective}-{target}/knowledge.md` を `Read` で読み込む
   - **読み込み失敗**（ファイル不在）→ knowledge.md を初期化して Phase 1A へ
   - **読み込み成功** → Phase 1B へ

#### knowledge.md の初期化（ファイル不在時のみ）

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/reviewer_optimize/templates/knowledge-init-template.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{knowledge_path}`: `prompt-improve/{perspective}-{target}/knowledge.md` の絶対パス
- `{approach_catalog_path}`: `.claude/skills/reviewer_optimize/approach-catalog.md` の絶対パス
- `{perspective}`, `{target}`, `{agent_definition_path}`: Phase 0 で決定した値

---

### Phase 1A: 初回 — 観点定義・初期プロンプト・バリアント作成（サブエージェントに委譲）

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/reviewer_optimize/templates/phase1a-variant-generation.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{perspective_template_path}`: `.claude/skills/reviewer_optimize/perspectives/{target}/{perspective}.md` の絶対パス
- `{perspective_path}`: `prompt-improve/{perspective}-{target}/perspective.md` の絶対パス
- `{agent_definition_path}`: Phase 0 で決定したエージェント定義ファイルの絶対パス
- `{approach_catalog_path}`: `.claude/skills/reviewer_optimize/approach-catalog.md` の絶対パス
- `{perspective}`, `{target}`: Phase 0 で決定した値

**標準モード**: サブエージェントの返答を `AskUserQuestion` でユーザーに提示し、確認を得る。
**高速モード**: サブエージェントの返答をテキスト出力のみ行い、確認なしで Phase 2 へ進む。

---

### Phase 1B: 2回目以降 — ナレッジ駆動バリアント作成

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/reviewer_optimize/templates/phase1b-variant-generation.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{knowledge_path}`: `prompt-improve/{perspective}-{target}/knowledge.md` の絶対パス
- `{agent_definition_path}`: Phase 0 で決定したエージェント定義ファイルの絶対パス
- `{approach_catalog_path}`: `.claude/skills/reviewer_optimize/approach-catalog.md` の絶対パス

**標準モード**: サブエージェントの返答を `AskUserQuestion` でユーザーに提示し、確認を得る。
**高速モード**: サブエージェントの返答をテキスト出力のみ行い、確認なしで Phase 2 へ進む。

---

### Phase 2: テスト対象文書の生成（サブエージェントに委譲）

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/reviewer_optimize/templates/phase2-test-document.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{test_document_guide_path}`: `.claude/skills/reviewer_optimize/test-document-guide.md` の絶対パス
- `{perspective_path}`: `prompt-improve/{perspective}-{target}/perspective.md` の絶対パス
- `{perspective_source_path}`: `.claude/skills/reviewer_optimize/perspectives/{target}/{perspective}.md` の絶対パス（問題バンクを含むソースファイル）
- `{knowledge_path}`: `prompt-improve/{perspective}-{target}/knowledge.md` の絶対パス
- `{test_document_save_path}`: `prompt-improve/{perspective}-{target}/test-document-round-{NNN}.md` の絶対パス（NNN = 累計ラウンド数 + 1）
- `{answer_key_save_path}`: `prompt-improve/{perspective}-{target}/answer-key-round-{NNN}.md` の絶対パス
- `{target}`: Phase 0 で決定した値

**標準モード**: サブエージェントの返答を `AskUserQuestion` でユーザーに提示し、確認する。
**高速モード**: サブエージェントの返答をテキスト出力のみ行い、確認なしで Phase 3 へ進む。

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
以下の手順でレビューを実行してください:

1. Read で {prompt_path} を読み込み、その内容に従ってレビューを実行してください
2. Read で {test_doc_path} を読み込み、レビュー対象としてください
3. レビュー結果を Write で {result_path} に保存してください
4. 最後に「保存完了: {result_path}」とだけ返答してください
```

- `{prompt_path}`: 評価対象プロンプトの絶対パス
- `{test_doc_path}`: テスト対象文書の絶対パス（`prompt-improve/{perspective}-{target}/test-document-round-{NNN}.md`）
- `{result_path}`: `prompt-improve/{perspective}-{target}/results/v{NNN}-{name}-run{N}.md`

全サブエージェント完了後、以下をテキスト出力する:

```
評価完了: {成功数}/{総数} タスク成功。Phase 4（採点）に進みます。
```

---

### Phase 4: 採点（サブエージェントの並列実行）

Phase 4 開始時に以下をテキスト出力する:

```
## Phase 4: 採点
- 採点タスク数: {N}（プロンプトごとに1タスク）
```

プロンプトごとに1つの採点サブエージェントを `Task` で並列起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

各サブエージェントへの指示: `.claude/skills/reviewer_optimize/templates/phase4-scoring.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{scoring_rubric_path}`: `.claude/skills/reviewer_optimize/scoring-rubric.md` の絶対パス
- `{answer_key_path}`: `prompt-improve/{perspective}-{target}/answer-key-round-{NNN}.md` の絶対パス
- `{perspective_path}`: `prompt-improve/{perspective}-{target}/perspective.md` の絶対パス
- `{result_run1_path}`, `{result_run2_path}`: 各プロンプトの Run1/Run2 結果ファイルの絶対パス
- `{scoring_save_path}`: `prompt-improve/{perspective}-{target}/results/v{NNN}-{name}-scoring.md`
- `{prompt_name}`: 評価対象プロンプトの名前

全採点サブエージェントの完了を待ち、各サブエージェントの返答（スコアサマリ）をテキスト出力する。Phase 5 へ進む。

---

### Phase 5: 分析・推奨判定・レポート作成（サブエージェントに委譲）

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/reviewer_optimize/templates/phase5-analysis-report.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{scoring_rubric_path}`: `.claude/skills/reviewer_optimize/scoring-rubric.md` の絶対パス
- `{knowledge_path}`: `prompt-improve/{perspective}-{target}/knowledge.md` の絶対パス
- `{scoring_file_paths}`: Phase 4 で保存された採点ファイルのパス一覧
- `{report_save_path}`: `prompt-improve/{perspective}-{target}/reports/round-{NNN}-comparison.md`

サブエージェント完了後、サブエージェントの返答（7行サマリ）をテキスト出力してユーザーに提示する。Phase 6 へ進む。

---

### Phase 6: プロンプト選択・デプロイ・次アクション（親で実行）

#### ステップ1: プロンプト選択とデプロイ

Phase 5 のサブエージェント返答（7行サマリ）を基に、`AskUserQuestion` でユーザーに提示する:

- 性能表（各プロンプトの Mean, SD, 安定性判定）
- 推奨プロンプトとその推奨理由
- 収束判定（該当する場合は「最適化が収束した可能性あり」を付記）

選択肢: 評価した全プロンプト名（ベースライン含む）を列挙。推奨プロンプトの選択肢に「(推奨)」を付記。

ユーザーの選択に応じて:
- **ベースライン以外を選択した場合**: `Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "haiku"`）:
  ```
  以下の手順でプロンプトをデプロイしてください:
  1. Read で {selected_prompt_path} を読み込む
  2. ファイル先頭の <!-- Benchmark Metadata ... --> ブロックを除去する
  3. {agent_definition_path} に Write で上書き保存する
  4. 「デプロイ完了: {agent_definition_path}」とだけ返答する
  ```
  - `{selected_prompt_path}`: ユーザーが選択したプロンプトファイルの絶対パス
  - `{agent_definition_path}`: Phase 0 で決定したエージェント定義ファイルの絶対パス
- **ベースラインを選択した場合**: 変更なし

#### ステップ2: ナレッジ更新と次アクション選択（並列実行）

以下の2つを同時に実行する:

**A) ナレッジ更新サブエージェント**

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/reviewer_optimize/templates/phase6a-knowledge-update.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{knowledge_path}`: `prompt-improve/{perspective}-{target}/knowledge.md` の絶対パス
- `{report_save_path}`: `prompt-improve/{perspective}-{target}/reports/round-{NNN}-comparison.md`
- `{recommended_name}`, `{judgment_reason}`: Phase 5 のサブエージェント返答の recommended と reason

**B) 次アクション選択（親で実行）**

`AskUserQuestion` でユーザーに確認する:
- 選択肢:
  1. **次ラウンドへ** — 続けて最適化を実行する
  2. **終了** — 最適化を終了する
- 収束判定が「収束の可能性あり」の場合はその旨を付記する

ナレッジ更新サブエージェントの完了を待ってから:
- 「次ラウンド」の場合: Phase 1B に戻る
- 「終了」の場合: 以下の最終サマリを出力してスキル完了

```
## 最適化完了サマリ
- 対象: {perspective}-{target}
- 累計ラウンド数: {N}
- 最終採用プロンプト: {prompt名}
- 最終スコア: Mean={X.X}, SD={X.X}
- 初回からの改善: {+X.Xpt}
- 主要な効果的変化: {knowledge.md の上位項目}
```
