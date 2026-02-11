---
allowed-tools: Glob, Grep, Read, Write, Edit, Task, AskUserQuestion
description: サブエージェントの動作を定義するmdファイルを作成・評価・改善し、性能向上の知見を蓄積するスキル
---

任意のエージェント定義ファイル（mdファイル）を新規作成または既存改善し、テストシナリオに対する性能を反復的に比較評価して最適化します。各ラウンドで得られた知見を `knowledge.md` に蓄積し、3ラウンドの最適化を行います。

## 使い方

```
/agent_create [agent_path]
```

- `agent_path`: 既存エージェント定義ファイルのパス（省略時は新規作成モード）

## コンテキスト節約の原則

1. **参照ファイルは使用するPhaseでのみ読み込む**（先読みしない）
2. **大量コンテンツの生成はサブエージェントに委譲する**
3. **サブエージェントからの返答は最小限にする**（詳細はファイルに保存させる）
4. **親コンテキストには要約・メタデータのみ保持する**
5. **サブエージェント間のデータ受け渡しはファイル経由で行う**（親を中継しない）

## ワークフロー

Phase 0 で初回/継続を判定し、初回は Phase 1A、継続は Phase 1B に進みます。Phase 2（テストセット作成）は初回のみ実行。その後 Phase 3 → 4 → 5 → 6 を順に実行します。

---

### Phase 0: 初期化・状態検出

1. 引数から `agent_path` を取得する（未指定の場合は `AskUserQuestion` で新規作成/既存改善を確認）
2. モード分岐:
   - **新規作成**: `AskUserQuestion` で以下をヒアリングする
     - エージェントの目的・役割
     - 想定される入力と期待される出力
     - 使用ツール・制約事項
     結果を `{user_requirements}` として保持する
   - **既存改善**: `agent_path` のファイルを Read で読み込み、以下の要素をチェックする
     - 目的/ロール定義、実行基準、出力ガイドライン、行動姿勢
     不足要素がある場合は `AskUserQuestion` でヒアリングする。結果を `{user_requirements}` として保持する
3. `{agent_name}` を決定する（ファイル名の拡張子を除いた部分 or ユーザー指定）
4. 作業ディレクトリ `prompt-improve/{agent_name}/` を確認する
5. `prompt-improve/{agent_name}/knowledge.md` を Read で読み込む
   - **読み込み失敗**（ファイル不在）→ knowledge.md を初期化して Phase 1A へ
   - **読み込み成功** → Phase 1B へ
6. 実行モードを `AskUserQuestion` で確認する:
   - **標準モード**: 各Phase で中間確認を行う
   - **高速モード**: 中間確認をスキップし、テストセット承認・デプロイ判定・次アクション選択のみ確認する

#### knowledge.md の初期化（ファイル不在時のみ）

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_create/templates/knowledge-init-template.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{knowledge_path}`: `prompt-improve/{agent_name}/knowledge.md` の絶対パス
- `{approach_catalog_path}`: `.claude/skills/agent_create/approach-catalog.md` の絶対パス
- `{agent_name}`, `{agent_path}`, `{agent_purpose}`: Phase 0 で決定した値

---

### Phase 1A: 初回 — ベースライン作成 + バリアント生成（サブエージェントに委譲）

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_create/templates/phase1a-variant-generation.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{user_requirements}`: Phase 0 で収集した要件テキスト
- `{agent_path}`: エージェント定義ファイルの絶対パス（存在しない場合は「新規」と指定）
- `{prompts_dir}`: `prompt-improve/{agent_name}/prompts` の絶対パス
- `{approach_catalog_path}`: `.claude/skills/agent_create/approach-catalog.md` の絶対パス
- `{proven_techniques_path}`: `.claude/skills/agent_create/proven-techniques.md` の絶対パス
- `{reference_agent_path}`: `.claude/agents/security-design-reviewer.md` の絶対パス（構造参考）
- `{agent_name}`: Phase 0 で決定した値

**標準モード**: サブエージェントの返答を `AskUserQuestion` でユーザーに提示し、確認を得る。
**高速モード**: サブエージェントの返答をテキスト出力のみ行い、確認なしで Phase 2 へ進む。

---

### Phase 1B: 継続 — 知見ベースのバリアント生成

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_create/templates/phase1b-variant-generation.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{knowledge_path}`: `prompt-improve/{agent_name}/knowledge.md` の絶対パス
- `{agent_path}`: エージェント定義ファイルの絶対パス
- `{prompts_dir}`: `prompt-improve/{agent_name}/prompts` の絶対パス
- `{approach_catalog_path}`: `.claude/skills/agent_create/approach-catalog.md` の絶対パス

**標準モード**: サブエージェントの返答を `AskUserQuestion` でユーザーに提示し、確認を得る。
**高速モード**: サブエージェントの返答をテキスト出力のみ行い、確認なしで Phase 3 へ進む。

---

### Phase 2: テストセット作成（初回のみ実行、サブエージェントに委譲）

既に `prompt-improve/{agent_name}/test-set.md` が存在する場合はスキップして Phase 3 へ進む。

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_create/templates/phase2-test-set.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{test_scenario_guide_path}`: `.claude/skills/agent_create/test-scenario-guide.md` の絶対パス
- `{baseline_prompt_path}`: `prompt-improve/{agent_name}/prompts/v001-baseline.md` の絶対パス
- `{knowledge_path}`: `prompt-improve/{agent_name}/knowledge.md` の絶対パス
- `{test_set_save_path}`: `prompt-improve/{agent_name}/test-set.md` の絶対パス
- `{rubric_save_path}`: `prompt-improve/{agent_name}/rubric.md` の絶対パス
- `{agent_name}`: Phase 0 で決定した値

**テストセットの承認**: モードに関わらず必ず `AskUserQuestion` でユーザー承認を得る。テストセットが評価の妥当性を決定するため、スキップ不可。

---

### Phase 3: 並列評価実行

Phase 3 開始時に以下をテキスト出力する:

```
## Phase 3: 並列評価実行
- 評価タスク数: {N}（3プロンプト × 2回）
- 実行プロンプト: {プロンプト名リスト}
```

3つのプロンプト（ベースライン1 + バリアント2）をそれぞれ2回ずつ `Task` ツールで並列実行する（全て同一メッセージ内で起動）:
- 並列数 = 3プロンプト × 2回 = 6タスク
- `subagent_type: "general-purpose"`, `model: "sonnet"`

各サブエージェントへの指示:

```
以下の手順でタスクを実行してください:

1. Read で {prompt_path} を読み込み、その内容をあなたの行動指針として従ってください
2. Read で {test_set_path} を読み込んでください
3. テストセット内の全シナリオ（T01, T02, ... ）を順番に処理してください:
   - 各シナリオの Input セクションを入力として、行動指針に従って処理する
   - 結果を Write で {result_dir}/v{NNN}-{name}-t{TNN}-run{R}.md に保存する
     （{TNN} は各シナリオの ID。例: T01 → t01, T02 → t02）
4. 全シナリオの処理完了後、「保存完了: {シナリオ数}シナリオ」とだけ返答してください
```

- `{prompt_path}`: 評価対象プロンプトの絶対パス
- `{test_set_path}`: `prompt-improve/{agent_name}/test-set.md` の絶対パス
- `{result_dir}`: `prompt-improve/{agent_name}/results` の絶対パス
- `{NNN}`: プロンプトのバージョン番号（例: 001）
- `{name}`: プロンプトの名前部分（例: baseline, variant-structured-output）
- `{R}`: 実行回数（1 または 2）

全サブエージェント完了後、以下をテキスト出力する:

```
評価完了: {成功数}/{総数} タスク成功。Phase 4（採点）に進みます。
```

---

### Phase 4: 採点（サブエージェントの並列実行）

プロンプトごとに1つの採点サブエージェントを `Task` で並列起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

各サブエージェントへの指示: `.claude/skills/agent_create/templates/phase4-scoring.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{scoring_rubric_path}`: `.claude/skills/agent_create/scoring-rubric.md` の絶対パス
- `{rubric_path}`: `prompt-improve/{agent_name}/rubric.md` の絶対パス
- `{result_paths}`: 各プロンプトの Run1/Run2 × 全シナリオの結果ファイルパスリスト
- `{scoring_save_path}`: `prompt-improve/{agent_name}/results/v{NNN}-{name}-scoring.md`
- `{prompt_name}`: 評価対象プロンプトの名前

全採点サブエージェントの完了を待ち、各サブエージェントの返答（スコアサマリ）をテキスト出力する。Phase 5 へ進む。

---

### Phase 5: 分析・推奨判定・レポート作成（サブエージェントに委譲）

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_create/templates/phase5-analysis-report.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{scoring_rubric_path}`: `.claude/skills/agent_create/scoring-rubric.md` の絶対パス
- `{knowledge_path}`: `prompt-improve/{agent_name}/knowledge.md` の絶対パス
- `{scoring_file_paths}`: Phase 4 で保存された採点ファイルのパス一覧
- `{report_save_path}`: `prompt-improve/{agent_name}/reports/round-{NNN}-comparison.md`

サブエージェント完了後、サブエージェントの返答（7行サマリ）をテキスト出力してユーザーに提示する。Phase 6 へ進む。

---

### Phase 6: プロンプト選択・デプロイ・次アクション（親で実行）

#### ステップ1: プロンプト選択とデプロイ

Phase 5 のサブエージェント返答（7行サマリ）と、過去ラウンドの結果（knowledge.md から取得）を基に、`AskUserQuestion` でユーザーに提示する:

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

`.claude/skills/agent_create/templates/phase6a-knowledge-update.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{knowledge_path}`: `prompt-improve/{agent_name}/knowledge.md` の絶対パス
- `{report_save_path}`: `prompt-improve/{agent_name}/reports/round-{NNN}-comparison.md`
- `{recommended_name}`, `{judgment_reason}`: Phase 5 のサブエージェント返答の recommended と reason

**次に** 以下の2つを同時に実行する:

**B) スキル知見フィードバックサブエージェント**

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_create/templates/phase6b-proven-techniques-update.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{proven_techniques_path}`: `.claude/skills/agent_create/proven-techniques.md` の絶対パス
- `{knowledge_path}`: `prompt-improve/{agent_name}/knowledge.md` の絶対パス
- `{report_save_path}`: `prompt-improve/{agent_name}/reports/round-{NNN}-comparison.md`
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
## agent_create 最適化完了
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
