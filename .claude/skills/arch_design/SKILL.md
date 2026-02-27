---
allowed-tools: Glob, Grep, Read, Write, Edit, Task
description: 要件定義書からユーザーとの対話を通じてアーキテクチャ設計を行い、設計文書を生成するスキル
disable-model-invocation: true
---

要件定義書（`docs/project-definition/requirements.md`）を入力として、P1 決定項目カタログの 5 固定グループを依存順に議論し、アーキテクチャを確定する。技術選定が必要な判断ポイントでは `/adr_create` コマンドの実行をユーザーに提示し、別セッションでの実行を促す。ADR結果を読み込んで設計を継続し、最終的に `docs/project-definition/architecture.md` を生成する。5観点の設計レビューを経て品質を担保する。

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

## コンテキスト管理方針

| 方針 | 適用箇所 |
|------|---------|
| 遅延読み込み | requirements.md は Phase 0 で構造サマリのみ抽出。p1-decision-catalog.md は Phase 1 のグループ議論開始時に読込 |
| 親コンテキスト最小化 | Phase 2/3 のコンテンツ生成・レビューはサブエージェントに委譲。親には要約のみ返す |
| ファイル経由のデータ受渡し | Phase 1→2 は design-decisions.md 経由。Phase 3 のレビュー結果はファイル保存 |
| リセットポイント | Phase 1→2 の境界（全決定を design-decisions.md に統合し、Phase 2 はファイルのみ参照） |

## 品質ゲート

| # | ゲート名 | 配置 | チェック内容 |
|---|---------|------|------------|
| QG-1 | 入力品質 | Phase 0 Step 1 | requirements.md の存在・Confirmed・SR/NFR存在 |
| QG-2 | ADR整合性 | Phase 1（各ADR読込後） | 新ADRが既存決定・他ADR・制約と矛盾しないか |
| QG-3 | 設計完全性 | Phase 1 完了前 | 全SR/NFR/IFが設計でカバーされているか + 孤立コンポーネント検出 |
| QG-3b | 技術選定の整合性 | Phase 1 完了前（QG-3後） | 技術的互換性・制約との適合性・既知の落とし穴 |
| QG-4 | トレーサビリティ | Phase 2 Step 2 | architecture.md の全SR/NFRに対応設計が記載されているか |
| QG-5 | 5観点レビュー | Phase 3 | security, performance, consistency, reliability, structural-quality |

## ワークフロー

Phase 0（初期化）→ 1（対話的アーキテクチャ設計）→ 2（設計文書生成）→ 3（設計レビュー）→ 4（出力・完了）

---

### Phase 0: 初期化

**目的**: 入力の検証、コンテキスト抽出、議論スコープの確認

#### Step 1: 入力ファイルの読み込みと検証

1. パス変数の設定（`{input_path}`, `{output_path}`, `{adr_dir}`, `{work_dir}`, `{skill_dir}`）
2. `{input_path}` = `docs/project-definition/requirements.md` を Read
   - 不在 → エラー終了
   - Draft → エラー終了
3. **QG-1**: SR 0 件 → エラー終了。Must UC 0 件 → 警告。NFR 0 件 → 警告

#### Step 2: 構造サマリの抽出

requirements.md から以下を抽出し親コンテキストに保持（全文は保持しない）:
- `{title}`, `{problem_summary}`, `{approach}`, `{constraints}`, `{scope_must}`, `{scope_excluded}`
- `{uc_list}`, `{actors_and_interfaces}`, `{sr_list}`, `{nfr_list}`, `{ir_list}`

#### Step 3: 既存 ADR の確認

`{adr_dir}` を Glob し、既存 ADR の「決定」セクションのみ抽出して `{existing_adrs}` に保持。

#### Step 4: Phase 0 完了サマリと議論スコープの確認

Phase 0 で抽出したメタデータと P1 カタログの 5 グループを提示し、要件と照らして含める/除外するグループを確認する。

```
### Phase 0 完了
- 入力: {input_path}
- 機能要件: SR {N}件
- 非機能要件: NFR {N}件
- インターフェース要件: IR {N}件
- 制約: {N}件
- 既存ADR: {N}件

### 議論スコープ

| # | グループ | 項目数 | 含める |
|---|---------|--------|--------|
| 1 | アーキテクチャ基盤 | 9 | ✓ |
| 2 | 技術スタック・インフラ | 12 | ✓ |
| 3 | フロントエンドエコシステム | 11 | ✓ |
| 4 | プロジェクト構成 | 2 | ✓ |
| 5 | AI 統合基盤 | 5 | {要件に基づく判断} |

修正があればお知らせください。問題なければ「ok」と回答してください。
```

`Bash` で `mkdir -p {work_dir}` を実行。承認後、スコープ計画を `{work_dir}/scope-plan.md` に保存。

**ユーザーチェックポイントの根拠**: スコープ決定は全後続フェーズの方向を規定する。方向転換コスト最大。

---

### Phase 1: 対話的アーキテクチャ設計

**目的**: P1 カタログの各グループを依存順に議論し、全項目の設計を確定する

#### グループ議論のフロー

含まれるグループを順に以下のパターンで議論する:

##### 1. グループ提示

`{skill_dir}/references/p1-decision-catalog.md` から当該グループの項目テーブルを参照し、提示する。既存 ADR で解決済みの項目があればマークする。

##### 2. 項目ごとの判断

各項目について、要件・制約・既存決定から以下を判断する:

- **直接決定**: 制約から選択肢が 1 つに絞られる場合。根拠を示して決定する。決定内容が後続グループの項目の ADR 要否や N/A 判定に影響する場合は更新する（例: フルスタック FW 採用 → Group 3 のルーティング設計が N/A に）
- **ADR 提案**: 複数の有力な候補があり、トレードオフ分析が必要な場合
- **N/A**: 要件上該当しない場合（例: フルスタック FW 採用時のルーティング設計）。スキップ理由を明示

##### 3. ADR の提案とグルーピング

ADR が必要な項目は、関連する項目をまとめて 1 つの ADR 提案にする。

```
### 技術選定: {選定ポイント名}

この判断は選択肢のトレードオフ分析が必要です。
以下のコマンドを **別セッション** で実行してください:

`/adr_create {選定ポイント名}。スコープ: {対象項目リスト}。制約: {確定済み決定から導出した制約}`

完了したら「完了」と回答してください。
```

ADR グルーピングの判断基準:
- 同一の ADR で解決すべき: 選択肢の組み合わせが相互に制約し合う項目（例: 言語 + FW + ランタイム）
- 別の ADR にすべき: 独立に判断でき、組み合わせの影響が小さい項目（例: DB 選定と FE FW 選定）

##### 4. ADR 読込と整合性検証

ユーザーが「完了」と回答したら:

1. `{adr_dir}` を Glob し、新 ADR を特定
2. 「決定」「受け入れたトレードオフ」セクションのみ Read
3. **QG-2**: 既存決定・他 ADR・`{constraints}` との矛盾検証
   - 矛盾検出時: ユーザーに提示し解決方法を相談
4. 決定を `{tech_decisions}` に追加
5. **後続影響チェック**: ADR の決定内容が後続グループの項目に影響するか確認する。影響がある場合は、当該項目の ADR 要否・N/A 判定を更新し、ユーザーに提示する
   - 例: Cloudflare Access 採用 → 認証ライブラリの選択肢が変化
   - 例: BaaS 採用 → 複数グループの項目が N/A またはスコープ変更

##### 5. グループ確認

グループ内の全項目を議論後、グループ決定サマリを提示:

```
### {グループ名} サマリ

| 項目 | 決定 | ADR | 根拠 |
|------|------|-----|------|
| ... | ... | ... | ... |

修正があればお知らせください。問題なければ「ok」と回答してください。
```

**ユーザーチェックポイントの根拠**: 各グループの決定は後続グループの前提になるため、方向転換コストが高い。

#### QG-3: 設計完全性ゲート（Phase 1 完了前）

全グループ議論後:

1. `{sr_list}` の全 Must SR に対応コンポーネントが特定されているか
2. `{nfr_list}` の全 NFR に対応する設計戦略が存在するか
3. `{actors_and_interfaces}` の全外部 IF に統合設計が存在するか
4. 議論中に追加したコンポーネントのうち、いずれの SR にもトレースできないもの（孤立コンポーネント）がないか

```
### 設計完全性チェック

| チェック | 結果 | 詳細 |
|---------|------|------|
| SR網羅 | {M}/{N} | 全Must SRに対応するコンポーネントが存在するか |
| NFR対応 | {M}/{N} | 全NFRに対応する設計戦略が存在するか |
| IF対応 | {M}/{N} | 全外部インターフェース(IF)に統合設計が存在するか |
| 孤立コンポーネント | {N}件 | SRにトレースできないコンポーネントがないか |
```

未カバー項目がある場合、各項目を個別に提示する:

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

#### QG-3b: 技術選定の整合性検証（Phase 1 完了前、QG-3 後）

QG-3 通過後、確定した全決定の組み合わせに対して以下の 3 観点を検証する:

| # | 観点 | チェック内容 | 検出例 |
|---|------|------------|--------|
| 1 | 技術的互換性 | 確定した技術スタックの組み合わせに、既知の非互換・制約違反がないか | サーバーレス + WebSocket 常時接続、Edge Runtime + 重い ORM |
| 2 | 制約との適合性 | 技術選定がプロジェクトの前提（個人開発・MVP 等）に対して過剰・不適合でないか | 個人開発で Kubernetes、MVP で独自認証基盤 |
| 3 | 既知の落とし穴 | 確定した技術の組み合わせに、よく報告される失敗パターンがないか | JWT + ログアウト無効化困難、Next.js App Router + クライアント状態管理の不整合 |

```
### 技術選定の整合性検証

| # | 観点 | 結果 | 詳細 |
|---|------|------|------|
| 1 | 技術的互換性 | {OK / 問題あり {N}件} | {問題の概要} |
| 2 | 制約との適合性 | {OK / 問題あり {N}件} | {問題の概要} |
| 3 | 既知の落とし穴 | {OK / 注意 {N}件} | {落とし穴の概要} |
```

問題がある場合は個別に提示し対応を確認する:

```
### 技術的互換性の問題: {問題名}
- **関連する決定**: {決定 A} + {決定 B} (+ {決定 C})
- **問題**: {非互換・制約違反の具体的な内容}
- **対応案**: {決定の変更 / 設計上の回避策 / リスク受容}

対応方針を選んでください。
```

**QG-5（設計レビュー）との役割分担**:
- QG-3b: 技術選定の組み合わせに対する検証（Phase 1 の決定に対して実施。文書化前）
- QG-5: 設計文書に対する多観点レビュー（architecture.md に対して実施。文書化後）

#### Phase 1 完了サマリ

全 QG-3/3b 通過後、Phase 1 全体の決定を俯瞰するサマリを提示する:

```
### Phase 1 サマリ

- **アーキテクチャスタイル**: {確定内容}
- **技術スタック**: {各レイヤーの確定技術}（ADR {N}件）
- **コンポーネント**: {N}個
- **設計完全性**: SR {M}/{N}, NFR {M}/{N}, IF {M}/{N}

修正があればお知らせください。問題なければ「ok」と回答してください。
```

- 承認: Phase 1 確定情報の保存へ
- 修正指示: 修正を反映して再提示

**ユーザーチェックポイントの根拠**: Phase 1→2 はリセットポイント。グループ別確認とは別に、全体の方向性の最終確認が必要。

#### Phase 1 確定情報の保存

全決定を `{work_dir}/design-decisions.md` に Write:
- アーキテクチャ方針
- 技術決定一覧（各項目の確定内容 + ADR 参照）
- グループ別決定結果
- 出力セクション構成テーブル（Phase 2 で使用）

---

### Phase 2: 設計文書生成

**目的**: Phase 1 の確定情報を統合し `architecture.md` を生成する

#### Step 1: 文書生成（サブエージェント）

`Task`（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

```
`{skill_dir}/templates/generate-design.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{requirements_path}`: {input_path}
- `{decisions_path}`: {work_dir}/design-decisions.md
- `{template_path}`: {skill_dir}/references/output-template.md
- `{adr_dir}`: {adr_dir}
- `{output_save_path}`: {output_path}
```

#### Step 2: QG-4 トレーサビリティゲート

1. `{input_path}` から SR/NFR の ID 一覧を取得する
2. `{output_path}` のトレーサビリティセクションと突合する:
   - **機能要件カバレッジ**: 全 SR-ID が「対応コンポーネント」に記載されているか
   - **NFR 対応**: 全 NFR-ID に「実現方法」が記載されているか

```
### トレーサビリティ検証結果
- SR網羅: {M}/{N}件 — 未対応: {SR-ID リスト or なし}
- NFR対応: {M}/{N}件 — 未対応: {NFR-ID リスト or なし}
```

未対応がある場合はユーザーに提示し、設計追加 or 意図的除外を確認する。修正を Edit で反映した後、Step 3 へ。

#### Step 3: ユーザー確認

生成された `{output_path}` を Read し提示。修正指示があれば Edit で反映。

---

### Phase 3: 設計レビュー

**目的**: 5 観点の並列レビューで設計品質を担保する

#### Step 0: 準備

`{review_loop}` = 0

#### Step 1: 並列レビュー実行

5 つの `Task` を **1 メッセージで並列に** 起動（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

| 観点 | agent 定義 | 結果保存先 |
|------|-----------|-----------|
| security | `.claude/agents/security-design-reviewer.md` | `{work_dir}/review-security.md` |
| performance | `.claude/agents/performance-design-reviewer.md` | `{work_dir}/review-performance.md` |
| consistency | `.claude/agents/consistency-design-reviewer.md` | `{work_dir}/review-consistency.md` |
| reliability | `.claude/agents/reliability-design-reviewer.md` | `{work_dir}/review-reliability.md` |
| structural-quality | `.claude/agents/structural-quality-design-reviewer.md` | `{work_dir}/review-structural-quality.md` |

各レビューアーに `{skill_dir}/templates/review.md` を渡す。

#### Step 2: レビュー結果統合

`Task` で `{skill_dir}/templates/consolidate-reviews.md` を実行。

#### Step 3: 結果に応じた処理

- **pass**: Phase 4 へ
- **needs_revision** かつ `{review_loop}` < 2: `{skill_dir}/templates/fix-design.md` で修正 → `{review_loop}` += 1 → Step 1 へ
- **needs_revision** かつ `{review_loop}` >= 2: 手動修正を案内してスキル終了

---

### Phase 4: 出力・完了

#### Step 1: ステータス更新

`{output_path}` のステータスを `Draft` → `Confirmed` に Edit で変更する。

#### Step 2: クリーンアップ

`{work_dir}` 内の一時ファイルを削除（`rm -rf {work_dir}`）。

#### Step 3: 完了出力

```
## arch_design 完了
- 入力: {input_path}
- 出力: {output_path}
- ADR: {adr_dir} ({N}件)
- レビュー: {review_loop + 1}ラウンド, verdict: pass

次のステップ:
1. `/standards_design` で開発規約設計に進んでください
```
