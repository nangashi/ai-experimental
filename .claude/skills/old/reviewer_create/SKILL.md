---
allowed-tools: Glob, Grep, Read, Write, Edit, Task, AskUserQuestion, TeamCreate, TeamDelete, SendMessage, TaskCreate, TaskUpdate, TaskList, TaskGet
description: 新しいレビューエージェントの観点定義とエージェント定義を生成し、批判的レビューを経て agent_bench で最適化可能な状態にするスキル
---

指定された観点キーとレビュー対象に対して、観点定義（perspective）を生成し、チーム批判レビューでブラッシュアップした上で、初期エージェント定義を生成します。

## 使い方

```
/reviewer_create [key] [target]
```

- `key`: レビュー観点キー（例: security, accessibility, i18n, error-handling）
- `target`: レビュー対象（design = 設計書, code = 実装コード）

いずれかが未指定の場合は `AskUserQuestion` で確認してください。

## コンテキスト節約の原則

1. **大量コンテンツの生成はサブエージェントに委譲する**
2. **サブエージェントからの返答は最小限にする**（詳細はファイルに保存させる）
3. **親コンテキストには要約・メタデータのみ保持する**

## ワークフロー

Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4 を順に実行します。

---

### Phase 0: 入力取得と既存確認

1. 引数から `key` と `target` を取得する（未指定の場合は `AskUserQuestion` で確認）
   - `target` は "code" または "design" のいずれかのみ（"both" は不可。両方作成する場合は2回実行する）

2. 既存ファイルの確認:
   - 観点定義: `.claude/skills/agent_bench/perspectives/{target}/{key}.md` を Read で確認
   - エージェント定義: `.claude/agents/{key}-{target}-reviewer.md` を Read で確認

3. 既存観点定義が**存在する場合** — `AskUserQuestion` で方針を確認:
   - **「ベースとして使用」**: ユーザーに変更要望を入力してもらい、`{user_requirements}` を以下で構成する:
     ```
     ## 既存の観点定義（ベース）
     {既存perspective内容}

     ## ユーザーの変更要望
     {ユーザー入力}
     ```
   - **「新規作成」**: 既存を無視。現行通りユーザーから要件テキストまたは参考ファイルパスを取得し `{user_requirements}` を構成
   - **「批判レビューのみ」**: Phase 1 をスキップし Phase 2 へ直行（既存perspectiveをそのまま批判レビュー）
   - エージェント定義も存在する場合は上書き確認も行う。拒否されたらスキル終了

4. 既存観点定義が**存在しない場合** — 現行通り:
   - `AskUserQuestion` で観点の説明テキストまたは参考ファイルパスを取得
   - ファイルパスの場合は Read で内容を取得し `{user_requirements}` として保持

5. 既存perspectiveの境界分析用データ収集:
   - Glob で `.claude/skills/agent_bench/perspectives/{target}/*.md` を列挙
   - 各ファイルの `## 概要` と `## 評価スコープ` セクションを Grep/Read で抽出
   - `{existing_perspectives_summary}` としてテキストにまとめて保持（Phase 2 で使用）

---

### Phase 1: 観点定義の初期生成（サブエージェントに委譲）

Phase 0 で「批判レビューのみ」が選択された場合はこの Phase をスキップする。

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/reviewer_create/templates/generate-perspective.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{key}`: 観点キー
- `{target}`: レビュー対象（design or code）
- `{user_requirements}`: ユーザーの要件説明テキスト（既存perspectiveベースの場合はその内容+変更要望を含む）
- `{perspective_save_path}`: `.claude/skills/agent_bench/perspectives/{target}/{key}.md` の絶対パス
- `{reference_perspective_path}`: `.claude/skills/agent_bench/perspectives/{target}/security.md` の絶対パス（構造参考用。存在しない場合は `.claude/skills/agent_bench/perspectives/design/security.md` を使用する）

サブエージェント完了後、返答内容をテキスト出力する。

---

### Phase 2: チーム批判レビュー

生成（または既存）の観点定義を4つの批判エージェントが評価し、議論を通じてブラッシュアップする。

#### Step 1: チーム作成

```
TeamCreate: team_name="rc-{key}-{target}"
```

#### Step 2: タスク作成

`TaskCreate` で以下の5つのタスクを作成する:

| タスク | 担当 | blockedBy |
|--------|------|-----------|
| 有効性批評 | effectiveness-critic | - |
| 網羅性批評 | completeness-critic | - |
| 明確性批評 | clarity-critic | - |
| 汎用性批評 | generality-critic | - |
| 批評統合・観点修正 | coordinator (self) | 上記4つ |

#### Step 3: 批判エージェント起動（4並列）

4つの `Task` を**1つのメッセージで並列に**起動する:

| name | subagent_type | テンプレート | 焦点 |
|------|--------------|-------------|------|
| `effectiveness-critic` | general-purpose | `critic-effectiveness.md` | 品質寄与度 + 他観点との境界 |
| `completeness-critic` | general-purpose | `critic-completeness.md` | 網羅性 + 未考慮事項検出 + 問題バンク |
| `clarity-critic` | general-purpose | `critic-clarity.md` | 表現明確性 + AI動作一貫性 |
| `generality-critic` | general-purpose | `critic-generality.md` | 汎用性 + 業界依存性フィルタ |

各エージェントへのプロンプト:
```
`.claude/skills/reviewer_create/templates/{テンプレートファイル名}` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- {perspective_path}: {観点定義の絶対パス}
- {existing_perspectives_summary}: {Phase 0で収集した既存観点の概要一覧テキスト}
- {key}: {観点キー}
- {target}: {レビュー対象}
- {task_id}: {担当タスクID}
```

各エージェントは完了後、コーディネーターに `SendMessage` で結果を送信し、`TaskUpdate` でタスクを完了にする。

#### Step 4: フィードバック分類

4件の批評を受信後、以下に分類する:
1. **重大な問題**: 観点定義の根本的修正が必要
2. **改善提案**: 品質向上に有効な変更
3. **確認（良い点）**: 現状維持でよい点

#### Step 5: コンフリクト検出と解決

批評間で矛盾する指摘を検出する。

**想定コンフリクトパターン:**
- 網羅性「スコープ項目を追加すべき」↔ 有効性「項目追加はフォーカスを薄める」
- 網羅性「問題バンクに不足検出型を追加」↔ 明確性「不足検出は基準が曖昧になりやすい」
- 汎用性「この項目は特定業界に依存するため削除すべき」↔ 網羅性「この項目は重要なカバレッジを提供する」

**コンフリクトがある場合:**
1. 関係する2名の批評エージェントに `SendMessage` で議論を依頼する
   - コンフリクトの内容を説明
   - 相手の名前を伝え、直接DMで議論するよう指示
   - 最大3往復で合意を目指すよう依頼
2. 合意に至った場合: その合意内容を反映
3. 合意に至らなかった場合: Step 7 のユーザー承認時にトレードオフを提示して選択を委ねる

**コンフリクトがない場合:** このステップをスキップ

#### Step 6: 観点定義の再生成

重大な問題または改善提案がある場合:
- `{user_requirements}` に批評フィードバックを追記する:
  ```
  ## 批評レビューからの改善要件
  - {反映すべき改善内容のリスト}
  ```
- Phase 1 と同じサブエージェント委譲パターンで再生成する

改善不要の場合: 現行perspectiveを維持

#### Step 6.5: 再評価ループ（最大3ラウンド）

Step 6 で観点定義を再生成した場合のみ実行する。改善不要で現行維持の場合はスキップ。

再生成された観点定義が批評フィードバックを適切に反映しているか、また新たな問題を生じていないかを検証する。

**ラウンドカウンタ**: `re_eval_round = 0`（最大3）

**ループ:**

1. `re_eval_round` をインクリメントする

2. 4名の批評エージェントに `SendMessage` で再評価を依頼する（4件を1ターンで送信）:

   各エージェントへのメッセージ:
   ```
   観点定義が批評フィードバックに基づいて再生成されました（ラウンド {re_eval_round}）。
   再評価をお願いします。

   手順:
   1. {perspective_path} を Read で読み込む
   2. 以下の観点で評価する:
      - 前回指摘した問題が適切に修正されているか
      - 修正によって新たな問題が発生していないか
      - 全体の整合性が維持されているか
   3. 以下のフォーマットで SendMessage で報告する:

   ### 再評価結果（{担当領域}・ラウンド{re_eval_round}）
   #### 前回指摘の反映状況
   - [指摘内容]: 解決済み / 未解決 / 部分的
   #### 新規の問題
   - （なければ「なし」）
   #### 改善提案
   - （なければ「なし」）
   #### 総合判定
   承認 / 要修正
   ```

3. 4件の再評価結果を受信後、判定する:
   - **全員「承認」**: ループを終了し Step 7 へ進む
   - **「要修正」あり** かつ `re_eval_round < 3`:
     再評価フィードバックを集約し、Step 6 と同じパターンで観点定義を再生成する → ループ先頭に戻る
   - **「要修正」あり** かつ `re_eval_round >= 3`:
     未解決の指摘事項を記録し、ループを終了して Step 7 へ進む

**ループ終了後**: `{re_eval_summary}` を構成する（Step 7 で使用）:
- 実施ラウンド数
- 各ラウンドの指摘件数と解決状況
- 最終的に未解決の指摘事項（もしあれば）

#### Step 7: ユーザー承認

批評レビューの結果と最終観点定義をユーザーに提示し、承認を得る。

1. **最終観点定義の提示**: 再生成後（または変更なしの場合は現行）のperspectiveファイルを Read し、全文をテキスト出力する
2. **議論の要約提示**: 以下を構造化して説明する
   - 各批評エージェントの主な指摘事項（有効性・網羅性・明確性・汎用性）
   - コンフリクトがあった場合: 論点と解決結果
   - 反映した改善内容のリスト
   - 反映しなかった指摘とその理由（もしあれば）
   - **再評価ループの結果**（実施した場合）: ラウンド数、検出・修正された問題、未解決の指摘事項
3. **`AskUserQuestion` で承認を確認する**:
   - 選択肢: 「承認（Phase 3 へ進む）」/「修正要望あり」
   - 「修正要望あり」の場合: ユーザーの修正要望を取得し、Step 6 に戻って再生成 → Step 6.5 の再評価ループ → 再度 Step 7 で承認確認

#### Step 8: チーム解散

1. 全メンバーに `SendMessage` で `shutdown_request` を送信する
2. `TeamDelete`

---

### Phase 3: エージェント定義生成（サブエージェントに委譲）

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/reviewer_create/templates/generate-agent-definition.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{key}`: 観点キー
- `{target}`: レビュー対象
- `{perspective_path}`: Phase 2 で確定した観点定義ファイルの絶対パス（`.claude/skills/agent_bench/perspectives/{target}/{key}.md`）
- `{reference_agent_path}`: `.claude/agents/security-design-reviewer.md` の絶対パス（構造参考用）
- `{agent_save_path}`: `.claude/agents/{key}-{target}-reviewer.md` の絶対パス

サブエージェント完了後、返答内容をテキスト出力する。

---

### Phase 4: 検証と完了サマリ

1. 生成ファイルの存在確認と構造検証:
   - 観点定義ファイルを Read し、以下を確認:
     - 必須セクション: `## 概要`, `## 評価スコープ`, `## スコープ外`, `## ボーナス/ペナルティの判定指針`, `## 問題バンク`
     - 問題バンクのテーブル行数が 8-10 件の範囲内か
   - エージェント定義ファイルを Read し、以下を確認:
     - YAMLフロントマターに `name`, `description`, `tools` が存在するか
   - **検証失敗時**: ユーザーに報告し、再生成するか手動修正するかを `AskUserQuestion` で確認する
     - 再生成を選択した場合: 該当 Phase（Phase 1 または Phase 3）に戻る

2. 完了サマリを出力する:

```
## reviewer_create 完了
- 観点: {key}（{target}）
- 観点定義: .claude/skills/agent_bench/perspectives/{target}/{key}.md
- エージェント定義: .claude/agents/{key}-{target}-reviewer.md
- 批評レビュー: 実施済み（有効性・網羅性・明確性・汎用性の4観点）
- 次のステップ: `/agent_bench .claude/agents/{key}-{target}-reviewer.md` で最適化を開始できます
```
