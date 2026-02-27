---
allowed-tools: Glob, Grep, Read, Write, Edit, Task
description: 要件定義書からユーザーとの対話を通じてアーキテクチャ設計を行い、設計文書を生成するスキル
disable-model-invocation: true
---

要件定義書（`docs/project-definition/requirements.md`）を入力として、ユーザーとの対話を通じてアーキテクチャ設計を行う。技術選定が必要な判断ポイントでは `/adr_create` コマンドの実行をユーザーに提示し、別セッションでの実行を促す。ADR結果を読み込んで設計を継続し、最終的に `docs/project-definition/architecture.md` を生成する。5観点の設計レビューを経て品質を担保する。

## 使い方

```
/arch_design
```

引数なし。`docs/project-definition/requirements.md` を入力として読み込む。

## 出力先

- `docs/project-definition/architecture.md`（固定パス）
- `docs/adr/`（技術選定ADR群、副産物）

## パス変数

- `{skill_dir}`: このファイルが存在するディレクトリの絶対パス
- `{input_path}`: `docs/project-definition/requirements.md` の絶対パス
- `{output_path}`: `docs/project-definition/architecture.md` の絶対パス
- `{adr_dir}`: `docs/adr/` の絶対パス
- `{work_dir}`: `.skill_output/arch_design/` の絶対パス

## コンテキスト節約の原則

1. **参照ファイルは使用するPhaseでのみ読み込む**（先読みしない）
2. **大量コンテンツの生成はサブエージェントに委譲する**（Phase 2, Phase 3）
3. **サブエージェントからの返答は最小限にする**（詳細はファイルに保存させる）
4. **親コンテキストには要約・メタデータのみ保持する**
5. **サブエージェント間のデータ受け渡しはファイル経由で行う**（親を中継しない）
6. **技術選定は別セッションの `/adr_create` に委譲する**。本セッションはADRの結論部分（決定セクション + 受け入れたトレードオフ）のみ読み込む
7. **`docs/project-definition/requirements.md` 全文を親コンテキストに保持しない**。Phase 0 で構造サマリのみ抽出し保持する

## 品質ゲート

| # | ゲート名 | 配置 | チェック内容 |
|---|---------|------|------------|
| QG-1 | 入力品質 | Phase 0 | requirements.md の存在・Confirmed・SR/NFR存在 |
| QG-2 | ADR整合性 | Phase 1（各ADR読込後） | 新ADRが既存の設計決定・他のADRと矛盾しないか |
| QG-3 | 設計完全性 | Phase 1（完了前） | 全SR/NFR/IRが設計でカバーされているか |
| QG-4 | トレーサビリティ | Phase 2（文書生成後） | design.md のトレーサビリティテーブルに未対応SR/NFRがないか |
| QG-5 | 5観点レビュー | Phase 3 | security, performance, consistency, reliability, structural-quality |

## ワークフロー

Phase 0（初期化・要件読込）→ 1（対話的アーキテクチャ設計）→ 2（設計文書生成）→ 3（5観点設計レビュー）→ 4（出力・完了）

---

### Phase 0: 初期化・要件読込

```
## Phase 0: 初期化
```

**目的:** 入力ファイルの存在・構造を検証し、以降の Phase で使うメタデータを抽出する

#### Step 1: 入力ファイルの読み込みと検証

1. `{input_path}` = `docs/project-definition/requirements.md` を設定する
2. `{output_path}` = `docs/project-definition/architecture.md` を設定する
3. `{adr_dir}` = `docs/adr/` を設定する
4. `{work_dir}` = `.skill_output/arch_design/` を設定する
5. `{input_path}` を Read する。不在の場合はエラー出力して終了:
   「`docs/project-definition/requirements.md` が見つかりません。先に `/requirement_define` を実行してください」
6. ステータスが `Confirmed` であることを確認する。`Draft` の場合:
   「ステータスが Draft です。`/requirement_define` で確定してから実行してください」と出力して終了

#### Step 2: 構造サマリの抽出

入力ファイルから以下のメタデータを抽出し、親コンテキストに保持する（全文は保持しない）:

- `{title}`: ドキュメントのタイトル（H1 見出し）
- `{problem_summary}`: 問題定義の1文要約
- `{approach}`: アプローチ選定の結果（採用した方針）
- `{constraints}`: 制約一覧テーブル
- `{scope_must}`: Must スコープ項目リスト
- `{scope_excluded}`: スコープ外項目リスト
- `{uc_list}`: ユースケース一覧テーブル（Must のみ）
- `{actors_and_interfaces}`: アクター一覧 + 外部インターフェース一覧
- `{sr_list}`: 機能要件テーブル（SR-ID, 要件, EARS型, トレース元）
- `{nfr_list}`: 非機能要件テーブル（NFR-ID, 観点, 要件, 測定基準）
- `{ir_list}`: インターフェース要件テーブル

#### Step 3: 既存ADRの確認

1. `{adr_dir}` を Glob で確認する
2. 既存ADRファイルがある場合は各ADRの「決定」セクションのみを抽出し `{existing_adrs}` に保持する
3. ない場合は `{existing_adrs}` = 空

#### Step 4: QG-1 入力品質ゲート

以下を検証する:

- SR が0件の場合: 「機能要件がありません。`/requirement_define` を実行してください」と出力して終了
- Must UCが0件の場合: 警告を提示し続行するか確認する
- NFR が0件の場合: 「NFRが定義されていません。設計の品質基準が不明確になります」と警告を提示する

テキスト出力:
```
## Phase 0 完了
- 入力: {input_path}
- 機能要件: SR {N}件
- 非機能要件: NFR {N}件
- インターフェース要件: IR {N}件
- 制約: {N}件
- 既存ADR: {N}件

Phase 1（対話的アーキテクチャ設計）に進みます。
```

---

### Phase 1: 対話的アーキテクチャ設計

```
## Phase 1: アーキテクチャ設計
```

**目的:** ユーザーとの対話で各設計次元を順に議論し、アーキテクチャを確定する。技術選定が必要な判断ポイントでは `/adr_create` コマンドの実行を促す

#### Step 0: スコープ分割計画

Phase 0 の構造サマリ（`{constraints}`, `{nfr_list}`, `{sr_list}`, `{ir_list}`, `{actors_and_interfaces}`）を基に、このプロジェクトに必要な設計次元を分析し、スコープ分割計画を作成する。

1. 「設計次元リファレンス」を参考にしつつ、要件からこのプロジェクトに必要な設計次元を導出する（要件に応じて追加・除外・分割・統合する）
2. 各次元について以下を定義する:
   - **決定対象**: この次元で何を決めるか
   - **対象外**: この次元では決めないこと（他の次元で扱う、またはスコープ外）
   - **依存先**: 他のどの次元の決定結果に依存するか
   - **ADR要否見込み**: 制約から一意に決まりそうか（不要）、トレードオフ分析が必要そうか（要）、現時点では判断できないか（未定）
3. 次元間の依存関係に基づき議論順序を決定する
4. 全体整合性を確認する:
   - 全 SR/NFR/IR がいずれかの次元でカバーされるか（漏れチェック）
   - 次元間のスコープに重複がないか（重複チェック）
   - 依存関係に循環がないか（循環チェック）

`Bash` で `mkdir -p {work_dir}` を実行する。

テキスト出力:
```
### スコープ分割計画

| # | 設計次元 | 決定対象 | 対象外 | 依存先 | ADR見込み |
|---|---------|---------|--------|--------|----------|
| 1 | {次元名} | {概要} | {概要} | {次元名リスト} | {要/不要/未定} |
| ... | | | | | |

**整合性チェック**: SR {M}/{N}, NFR {M}/{N}, IR {M}/{N} カバー / 重複 {N}件 / 循環 なし

修正があればお知らせください。問題なければ「ok」と回答してください。
```

- 承認: `{work_dir}/scope-plan.md` に Write で保存し、Step 1 へ
- 修正指示: 修正を反映して再提示

#### 次元導出ガイド

以下のルールで要件から設計次元を導出する。該当しないルールはスキップする:

1. **アーキテクチャスタイル**: 常に最初に決定する（他の全次元に影響）
2. **実行基盤**: 制約にコスト・ホスティング・実行環境への言及がある場合
3. **技術選定**: SR/NFRの実現に技術選択が必要なレイヤーごとに1次元。判断基準: 「このレイヤーで複数の技術候補があり、選択がNFR/制約に影響するか」
4. **セキュリティ/認証**: NFRにセキュリティ・認証・認可への言及がある場合
5. **外部統合**: IRが存在する、または外部システム連携がある場合
6. **可観測性**: NFRに監視・可観測性・ログへの要求がある場合。観測基盤（Datadog / Grafana Cloud / プラットフォーム標準等）の選定を含む。実行基盤の制約から自動的に決まる場合は独立次元にせず横断的関心事で扱う
7. **コンポーネント構成**: 全技術決定後、コンポーネント間の責務分割と依存関係を設計
8. **インターフェース設計**: コンポーネント構成確定後。SR/NFRの実現にAPIやインターフェース契約の設計が必要な場合。以下を含む:
   - 外部向け命名規則（APIパス・フィールド名・DBテーブル/カラム名のケーススタイル）
   - リソース定義（概念データモデル: フィールド、概念型、リソース間関連）
   - エンドポイント設計（メソッド、パス、認証要否、対応UC/SR）
   - 共通API規約（エラーレスポンス形式、ページネーション方式）

粒度の判断基準:
- 1次元 = 1つの独立した判断単位。その次元内で決定が相互に強く依存する
- 別の次元の決定を待たないと判断できない → 依存関係として定義
- 1次元の決定対象が3つ以上 → 分割を検討

#### Step 1: 各次元の対話的設計

スコープ分割計画の議論順序に従い、各次元を以下のパターンで議論する:

1. スコープ分割計画から当該次元のスコープ（決定対象・対象外）を提示する
2. Phase 0 の構造サマリ（`{constraints}`, `{nfr_list}`, `{sr_list}` 等）を基に、AIが適切な方式を1-2案提案する
3. 各案に理由（NFR/制約との対応）とトレードオフを明示する
4. ユーザーの承認を待つ

```
### {次元名}

**スコープ**: {スコープ分割計画の決定対象}
**対象外**: {スコープ分割計画の対象外}

{要件・制約からの分析に基づく提案}

**案1: {方式}**
- 理由: {NFR/制約との対応}
- トレードオフ: {弱点}

（代替案がある場合は案2も提示）

修正があればお知らせください。問題なければ「ok」と回答してください。
```

- 承認: 次の次元へ
- 修正指示: 修正を反映して再提示

#### ADR提案パターン

技術選定が必要な次元（複数の候補がありトレードオフ分析が必要な場合）では、以下のパターンで `/adr_create` の実行を促す:

```
### 技術選定: {選定ポイント名}

この判断は選択肢のトレードオフ分析が必要です。
以下のコマンドを**別セッション**で実行してください:

`/adr_create {選定ポイント名}。スコープ: {スコープ分割計画の当該次元の決定対象}。制約: {確定済みアーキテクチャ方針から導出した制約リスト}`

完了したら「完了」と回答してください。
```

**ADR不要の判断基準**: 制約やNFRから選択肢が1つに絞られる場合、ADRは不要。AIが根拠を示して直接決定する。

#### ADR読込と整合性検証

ユーザーが「完了」と回答したら:

1. `{adr_dir}` を Glob で確認し、新しいADRファイルを特定する
2. ADRファイルの「決定」セクション と「受け入れたトレードオフ」セクションのみを Read する（全文は読み込まない）
3. **QG-2: ADR整合性ゲート** — 新ADRの決定内容が以下と矛盾しないか検証する:
   - 既に確定したアーキテクチャ方針（例: サーバレス採用なのに常時起動前提のDB）
   - 他の確定済みADR（例: ホスティング基盤の制約と矛盾するDB選定）
   - `{constraints}` の制約（例: コスト制約違反）
   - 矛盾検出時はユーザーにテキスト出力する:
     「ADR '{ADR名}' の決定が '{矛盾対象}' と矛盾しています: {詳細}。どう解決しますか？」
4. 決定を `{tech_decisions}` に追加する
5. **スコープ影響チェック** — ADRの決定内容が、スコープ分割計画の未議論次元のスコープに影響するか確認する:
   - 影響がある場合: スコープ分割計画の該当次元の決定対象・対象外を更新し、ユーザーに提示する
     - 例: Cloudflare Access 採用 → 認証実装の次元のスコープが変化
   - `{work_dir}/scope-plan.md` を更新する
   - 影響がない場合: 次の次元へ進む

ADR不要で直接決定した場合も、決定内容が他次元のスコープに影響する場合は同様にスコープ影響チェックを行う。

#### QG-3: 設計完全性ゲート（Phase 1 完了前）

全次元の議論終了後、Phase 1 サマリ提示前に以下を検証する:

1. Phase 0 の `{sr_list}` の全 Must SR に対して、対応するコンポーネントが議論内で特定されているか
2. `{nfr_list}` の全 NFR に対して、対応する設計戦略（技術選定・パターン・構成）が存在するか
3. `{actors_and_interfaces}` の全外部インターフェース（IF）に対して、統合設計が存在するか
4. 議論で追加したコンポーネントのうち、いずれのSRにもトレースできないもの（孤立コンポーネント）がないか

```
### 設計完全性チェック

| チェック | 結果 | 詳細 |
|---------|------|------|
| SR網羅 | {M}/{N} | 全Must SRに対応するコンポーネントが存在するか |
| NFR対応 | {M}/{N} | 全NFRに対応する設計戦略が存在するか |
| IF対応 | {M}/{N} | 全外部インターフェース(IF)に統合設計が存在するか |
| 孤立コンポーネント | {N}件 | SRにトレースできないコンポーネントがないか |
```

未カバー項目がある場合、各項目を個別にテキスト出力する:

```
### 未カバー: {SR/NFR/IF-ID}
- **問題**: この{要件/NFR/IF}に対応する設計要素がありません
- **提案**: {追加すべきコンポーネント/戦略/統合設計}

対応しますか？
```

孤立コンポーネントがある場合:

```
### 孤立コンポーネント: {名前}
- **問題**: このコンポーネントはどのSRにもトレースできません
- **対応案**: 削除 / トレース元を追加

対応しますか？
```

#### Phase 1 完了サマリ

全次元を議論し、設計完全性チェックを通過したら:

```
### Phase 1 サマリ

- **アーキテクチャスタイル**: {確定内容}
- **技術スタック**: {各レイヤーの確定技術}（ADR {N}件）
- **コンポーネント**: {N}個
- **設計完全性**: SR {M}/{N}, NFR {M}/{N}, IF {M}/{N}

修正があればお知らせください。問題なければ「ok」と回答してください。
```

- 承認: Step（ファイル出力）へ
- 修正指示: 修正を反映して再提示

#### Phase 1 確定情報のファイル出力

1. Phase 1 の全確定情報を `{work_dir}/design-decisions.md` に Write で保存する。以下のセクションを含む:
   - スコープ分割計画サマリ（各次元の最終スコープと決定結果の対応）
   - アーキテクチャ方針
   - 技術決定一覧（各レイヤーの確定技術 + ADR参照）
   - 各次元の決定結果（Phase 1 の議論で確定した内容。次元ごとにセクションを作成）
   - 出力セクション構成テーブル（以下のフォーマット）

出力セクション構成テーブル:
```
## 出力セクション構成

| # | セクション名 | 対応する設計次元 | 含める内容 |
|---|------------|----------------|-----------|
| 1 | システム概要 | — | 問題定義・アプローチ |
| 2 | アーキテクチャスタイル・パターン | アーキテクチャスタイル | 選択したスタイル・パターン |
| 3 | 技術スタック | — | 全技術決定の一覧テーブル |
| 4 | {次元に対応するセクション名} | {次元名} | {方針・関連SR/NFR} |
| ... | | | |
| N | 横断的関心事 | — | ログ・エラーハンドリング等（該当するもののみ） |
| N+1 | 要件トレーサビリティ | — | SR/NFRカバレッジ |
```

テキスト出力:
```
## Phase 1 完了

Phase 2（設計文書生成）に進みます。
```

---

### Phase 2: 設計文書生成

```
## Phase 2: 設計文書生成
```

**目的:** Phase 1 で確定した全情報を統合し、`docs/project-definition/architecture.md` を生成する

#### Step 1: 文書生成（サブエージェントに委譲）

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

```
`{skill_dir}/templates/generate-design.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{requirements_path}`: {input_path} の絶対パス
- `{decisions_path}`: {work_dir}/design-decisions.md の絶対パス
- `{template_path}`: {skill_dir}/references/output-template.md の絶対パス
- `{adr_dir}`: {adr_dir} の絶対パス
- `{output_save_path}`: {output_path} の絶対パス
```

サブエージェントの返答: `result` + `sections_completed` + `sr_coverage` + `nfr_coverage` + `adr_references`

#### Step 2: QG-4 トレーサビリティゲート

生成された `{output_path}` の「要件トレーサビリティ」セクションを検証する:

1. `{input_path}` から SR/NFR の ID 一覧を取得する
2. `{output_path}` のトレーサビリティセクションと突合する:
   - **機能要件カバレッジ**: 全SR-IDが「対応コンポーネント」に記載されているか
   - **NFR対応**: 全NFR-IDに「実現方法」が記載されているか

```
### トレーサビリティ検証結果
- SR網羅: {M}/{N}件 — 未対応: {SR-ID リスト or なし}
- NFR対応: {M}/{N}件 — 未対応: {NFR-ID リスト or なし}
```

未対応がある場合はユーザーに提示し、設計追加 or 意図的除外を確認する。未対応を Edit で修正した後、Step 3 へ。

#### Step 3: ユーザー確認

1. `{output_path}` を Read し、ユーザーにテキスト出力する
2. 「修正があればお知らせください。問題なければ『ok』と回答してください。」
   - 修正指示あり: 内容を Edit で修正して再提示
   - 承認: Phase 3 へ

テキスト出力:
```
## Phase 2 完了

- 設計文書: {output_path}

Phase 3（設計レビュー）に進みます。
```

---

### Phase 3: 設計レビュー

```
## Phase 3: 設計レビュー
```

**目的:** 5観点の並列レビューで設計品質を担保する

#### Step 0: 準備

1. `{review_loop}` = 0

#### Step 1: 並列レビュー実行

以下の5つを `Task` ツールで **1つのメッセージで並列に** 起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

| 観点 | agent定義 | 結果保存先 |
|------|----------|-----------|
| security | `.claude/agents/security-design-reviewer.md` | `{work_dir}/review-security.md` |
| performance | `.claude/agents/performance-design-reviewer.md` | `{work_dir}/review-performance.md` |
| consistency | `.claude/agents/consistency-design-reviewer.md` | `{work_dir}/review-consistency.md` |
| reliability | `.claude/agents/reliability-design-reviewer.md` | `{work_dir}/review-reliability.md` |
| structural-quality | `.claude/agents/structural-quality-design-reviewer.md` | `{work_dir}/review-structural-quality.md` |

各レビューアーへのプロンプト:

```
`{skill_dir}/templates/review.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{perspective}`: {観点名}
- `{agent_definition_path}`: `.claude/agents/{perspective}-design-reviewer.md` の絶対パス
- `{design_path}`: {output_path} の絶対パス
- `{requirements_path}`: {input_path} の絶対パス
- `{findings_save_path}`: {work_dir}/review-{perspective}.md の絶対パス
```

5件全ての Task 完了後、各返答のサマリをテキスト出力する。

#### Step 2: レビュー結果統合

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

```
`{skill_dir}/templates/consolidate-reviews.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{review_paths}`: {work_dir}/review-security.md, {work_dir}/review-performance.md, {work_dir}/review-consistency.md, {work_dir}/review-reliability.md, {work_dir}/review-structural-quality.md の絶対パスリスト
- `{consolidated_save_path}`: {work_dir}/review-consolidated.md の絶対パス
```

サブエージェントの返答: `verdict` + `critical` + `significant` + `total` + `summary`

#### Step 3: 結果に応じた処理

**verdict: pass の場合**:
1. レビュー結果サマリをユーザーにテキスト出力する
2. Phase 4 へ進む

**verdict: needs_revision の場合**:
1. レビュー結果サマリ（Critical/Significant 指摘一覧）をユーザーにテキスト出力する
2. `{review_loop}` が 2 以上の場合:
   「設計レビューで重大な指摘が解消されませんでした。`{work_dir}/review-consolidated.md` を確認し、設計を手動で修正してから再実行してください」と出力し、スキル終了
3. Step 4 へ

#### Step 4: 設計修正

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

```
`{skill_dir}/templates/fix-design.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{design_path}`: {output_path} の絶対パス
- `{consolidated_path}`: {work_dir}/review-consolidated.md の絶対パス
- `{requirements_path}`: {input_path} の絶対パス
```

修正サマリをテキスト出力する。`{review_loop}` += 1。Step 1 に戻る（再レビュー）。

---

### Phase 4: 出力・完了

```
## Phase 4: 完了
```

#### Step 1: クリーンアップ

`{work_dir}` 内の一時ファイルを削除する（Bash: `rm -rf {work_dir}`）。

#### Step 2: 完了出力

```
## arch_design 完了
- 入力: {input_path}
- 出力: {output_path}
- ADR: {adr_dir} ({N}件)
- レビュー: {review_loop + 1}ラウンド, verdict: pass

次のステップ:
1. `/process_design` で開発プロセス設計に進んでください
2. `/extract_decisions` で設計判断記録を生成してください
```
