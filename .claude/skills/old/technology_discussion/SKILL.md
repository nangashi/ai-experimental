---
allowed-tools: Bash, Glob, Grep, Read, Write, Edit, Task, AskUserQuestion, TeamCreate, TeamDelete, TaskCreate, TaskUpdate, TaskList, SendMessage, WebSearch, WebFetch
description: 開発方針を複数の性格エージェントが直接議論して結論を導くスキル
---

性格ベースの思考スタイル（Pragmatist/Skeptic/Idealist/Connector）を持つ3エージェントが TeamCreate で直接議論し、メインエージェントがドメイン知識の供給とファシリテーションを行って多角的な結論を導きます。

## 使い方

```
/technology_discussion <topic>
```

- `topic`: 議論したい開発方針・技術的な議題（テキスト）

未指定の場合は `AskUserQuestion` で確認してください。

## コンテキスト節約の原則

1. **大量コンテンツの生成・分析はサブエージェントに委譲する**
2. **サブエージェントからの返答は最小限にする**（詳細はファイルに保存させる）
3. **親コンテキストには要約・メタデータのみ保持する**
4. **エージェント間のデータ受け渡しはファイル経由**（親を中継しない）

## ワークフロー

Phase 0 → 1 → 2 → 3 → 4 → 5 を順に実行します。

---

### Phase 0: 初期化

テキスト出力: `## Phase 0: 初期化`

1. 引数から `{topic}` を取得する（未指定の場合は AskUserQuestion で確認）
2. `{topic}` から `{topic_slug}` を生成する（英数字+ハイフン、30文字以内。日本語の場合はローマ字化または英訳）
3. `{work_dir}` = `.technology_discussion/{topic_slug}` の絶対パス
4. `{skill_dir}` = `.claude/skills/technology_discussion` の絶対パス
5. `mkdir -p {work_dir}` を実行する（Bash）
6. テキスト出力:
   ```
   議題: {topic}
   作業ディレクトリ: {work_dir}
   ```

---

### Phase 1: 情報収集（サブエージェントに委譲）

テキスト出力: `## Phase 1: 情報収集`

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

```
`{skill_dir}/templates/research-topic.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- {topic}: {値}
- {work_dir}: {値}
- {research_save_path}: {work_dir}/research.md の絶対パス
```

サブエージェント完了後、返答内容（サマリ）をテキスト出力する。

---

### Phase 2: 性格選択 + 論点整理

テキスト出力: `## Phase 2: 性格選択 + 論点整理`

#### Step 1: 性格選択

議題 `{topic}` の性質に基づいて、以下のテーブルから4性格のうち3つを選択する。`{selected_personalities}` に選択した3つの性格名（英語、小文字）をリストとして保持する。

| 議題の性質 | 推奨3性格 | 外す性格 | 判断基準 |
|-----------|----------|---------|---------|
| デフォルト | pragmatist, skeptic, idealist | connector | 迷ったらこれ。基本的な対立軸を確保 |
| 既存システムの改善・移行 | pragmatist, skeptic, connector | idealist | 既存資産との関連性・波及効果が重要 |
| 長期的アーキテクチャ決定 | skeptic, idealist, connector | pragmatist | 短期最適化より長期視点が必要 |
| リスク評価・障害対策 | pragmatist, skeptic, connector | idealist | 現実的リスク分析が最重要 |

テキスト出力:
```
選択した性格: {personality1}, {personality2}, {personality3}
（外した性格: {personality4} — 理由: {1文}）
```

#### Step 2: 専門性ヒント付与

議題に基づき、`{selected_personalities}` の各性格に1行の観点ヒントを生成する。`{hint_1}`, `{hint_2}`, `{hint_3}` に保持する。

形式: 「議論の中で特に{観点}面のトレードオフを掘り下げること」

テキスト出力:
```
専門性ヒント:
- {personality1}: {hint_1}
- {personality2}: {hint_2}
- {personality3}: {hint_3}
```

#### Step 3: 論点整理

`{work_dir}/research.md` を Read し、議題に関する具体的な論点（3-5個）を構造化する。各論点は以下の形式:

```markdown
## 論点1: {タイトル}
### 背景
（research.md からの関連情報）
### 想定される選択肢
- 選択肢A: {概要}
- 選択肢B: {概要}
```

`{work_dir}/discussion-points.md` に Write する。

テキスト出力: `論点: {N}個を整理しました`

---

### Phase 3: チーム議論（TeamCreate）

テキスト出力:
```
## Phase 3: チーム議論
- 参加者: {personality1}, {personality2}, {personality3}
- 最大ラウンド: 3
```

#### Step 1: チーム作成

1. TeamCreate: `team_name="td-{topic_slug}"`
2. TaskCreate × 3: 各性格エージェント用のタスク
   - subject: `{personality} の意見表明`
   - description: `Round 1: 各論点に対する立場を表明する`

#### Step 2: エージェント起動（3つ並列）

以下の3つの Task を**1つのメッセージで並列に**起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`, `team_name: "td-{topic_slug}"`）。

各エージェントの `name` は性格名（例: `pragmatist`）とする。

各エージェントのプロンプト:
```
あなたは開発方針の議論に参加するエージェントです。

## 性格
`{skill_dir}/personalities/{personality}.md` を Read で読み込み、その性格に徹底的に従ってください。
追加の観点ヒント: {hint_N}

## コンテキスト
以下のファイルを Read で読み込んでコンテキストを把握してください:
- `{work_dir}/research.md` — 議題に関する調査結果
- `{work_dir}/discussion-points.md` — 議論すべき論点

## Round 1 タスク
各論点に対する自分の立場を明確にし、根拠とともに述べてください。

1. `{work_dir}/round1-{personality}.md` に詳細な意見を Write で保存してください。フォーマット:
   各論点について:
   - 立場: {選択肢Xを支持 / 独自の提案}
   - 根拠: {具体的な理由}
   - 懸念: {他の選択肢に対する懸念}

2. 保存後、team-lead に SendMessage で意見のサマリ（各論点の立場を1行ずつ）を報告してください。

3. Round 1 完了後、team-lead からの次の指示を待ってください。追加のラウンドがある場合は指示に従ってください。
```

#### Step 3: Round 1 集約 + 対立点特定

3エージェントからのメッセージを受信後:

1. `{work_dir}/round1-*.md` を Glob で検出し、全て Read する
2. 論点ごとに対立点を特定する:
   - 3性格のうち2つ以上が同じ立場 → 合意（対立なし）
   - 全員が異なる立場、または2:1で分裂 → 対立あり
3. 対立点を `{work_dir}/conflicts.md` に以下の形式で Write する:

```markdown
# 対立点整理

## 合意済み論点
- 論点X: {合意内容}（{personality1}, {personality2}, {personality3} 全員一致 / {personality1}+{personality2} 一致）

## 対立論点
### 論点Y: {タイトル}
- {personality1}: {立場の要約}
- {personality2}: {立場の要約}
- {personality3}: {立場の要約}
- 対立の構造: {何が争点か}
```

4. テキスト出力: `Round 1 完了: 合意 {N}件, 対立 {M}件`

対立が0件の場合: Round 2, 3 をスキップし Step 6 へ進む。

#### Step 4: Round 2 — 対立点への反論

各エージェントに SendMessage で以下を送信する:

```
Round 2 です。対立点が見つかりました。

`{work_dir}/conflicts.md` を Read して対立点を確認してください。
また、他のエージェントの意見を確認してください:
- `{work_dir}/round1-{other_personality1}.md`
- `{work_dir}/round1-{other_personality2}.md`

対立している論点について、他のエージェントの意見を踏まえた上で:
1. 自分の立場を維持するか修正するか
2. 他のエージェントの意見への反論または同意
3. 妥協案があればその提示

を `{work_dir}/round2-{personality}.md` に Write し、team-lead に SendMessage でサマリを報告してください。
```

3エージェントからのメッセージを受信後:
- `{work_dir}/round2-*.md` を全て Read する
- 未解決の対立点を特定する（Round 2 で意見が変わらなかった論点）
- テキスト出力: `Round 2 完了: 解決 {N}件, 未解決 {M}件`

未解決が0件の場合: Round 3 をスキップし Step 6 へ進む。

#### Step 5: Round 3 — 未解決の直接議論（必要な場合のみ）

重要な未解決対立がある場合のみ実施する。対立する2エージェント間で直接議論させる。

対立する2エージェントを特定し、片方に SendMessage で以下を送信する:

```
Round 3 です。論点「{論点タイトル}」について {other_personality} と直接議論してください。

{other_personality} の Round 2 の意見: `{work_dir}/round2-{other_personality}.md` を Read してください。

あなたの立場と根拠を {other_personality} に直接 SendMessage で送信してください。
反応を受け取ったら、1回だけ返答してください（最大1往復）。

議論後、最終的な立場を `{work_dir}/round3-{personality}.md` に Write し、team-lead に SendMessage で結果を報告してください。
```

もう片方のエージェントにも同様に SendMessage する。

テキスト出力: `Round 3 完了`

#### Step 6: チーム解散

全エージェントに SendMessage で `type: "shutdown_request"` を送信する。全員の shutdown 完了を確認後、TeamDelete を実行する。

テキスト出力: `チーム解散完了`

---

### Phase 4: 結論統合 + フィードバック

テキスト出力: `## Phase 4: 結論統合 + フィードバック`

#### Step 1: 結論ドラフト生成（サブエージェントに委譲）

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

```
`{skill_dir}/templates/synthesize-conclusion.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- {topic}: {値}
- {work_dir}: {値}
- {discussion_points_path}: {work_dir}/discussion-points.md の絶対パス
- {draft_save_path}: {work_dir}/draft-conclusion.md の絶対パス
- {personalities}: {personality1},{personality2},{personality3}
```

サブエージェント完了後、返答内容（結論サマリ）をテキスト出力する。

#### Step 2: フィードバック収集（3並列 Task）

以下の3つの Task を**1つのメッセージで並列に**起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）。TeamCreate は使用しない。

各エージェントのプロンプト:
```
あなたは開発方針の議論のフィードバックを提供するエージェントです。

## 性格
`{skill_dir}/personalities/{personality}.md` を Read で読み込み、その性格に徹底的に従ってください。

## タスク
`{work_dir}/draft-conclusion.md` を Read し、自分の性格の観点から最終フィードバックを提供してください。

以下の観点でフィードバックしてください:
1. 結論は自分の性格の主要な懸念に対処しているか
2. 見落とされている重要な点はないか
3. 結論の修正提案（あれば具体的に）

フィードバックを `{work_dir}/feedback-{personality}.md` に Write してください。

返答は「フィードバック完了。重要な修正提案: {ある/なし}」の1行のみ。
```

3件全ての Task 完了後、テキスト出力: `フィードバック収集完了: {N}/3件`

#### Step 3: フィードバック反映

1. `{work_dir}/feedback-*.md` を全て Read する
2. 各フィードバックの修正提案を評価する:
   - 結論の論理的な欠陥を指摘している → 反映する
   - 新たなリスクや見落としを指摘している → 留意事項に追加する
   - 自分の性格の立場を繰り返しているだけ → 反映しない
3. 反映した内容をメモする

---

### Phase 5: 最終結論 + 完了

テキスト出力: `## Phase 5: 最終結論`

#### Step 1: 最終結論生成

`{work_dir}/draft-conclusion.md` を Read し、Phase 4 Step 3 のフィードバック反映結果を適用して `{work_dir}/final-conclusion.md` に Write する。

フォーマット:
```markdown
# {topic} — 議論結論

## 結論
（採用方針の明確な記述）

## 根拠
（各論点に対する判断理由。どの性格の意見をどう反映したか）

## 却下された代替案
（検討したが採用しなかった案と、その理由）

## 議論のポイント
（特に議論が白熱した論点と、どう決着したか）

## 留意事項
（結論を実行する際の注意点やリスク）
```

#### Step 2: 完了サマリ

テキスト出力:
```
## technology_discussion 完了
- 議題: {topic}
- 参加性格: {personality1}, {personality2}, {personality3}
- 論点: {N}個
- 議論ラウンド: {実施ラウンド数}
- 合意: {合意論点数}/{全論点数}
- 最終結論: {work_dir}/final-conclusion.md

### 結論サマリ
{final-conclusion.md の「結論」セクションの内容}
```
