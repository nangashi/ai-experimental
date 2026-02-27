---
allowed-tools: Glob, Grep, Read, Write, Edit, Task
description: アーキテクチャ設計書を入力として、実装に必要な具体的構造を対話的に設計し、基本設計書を生成するスキル
disable-model-invocation: true
---

アーキテクチャ設計書（`docs/project-definition/architecture.md`）と要件定義書（`docs/project-definition/requirements.md`）を入力として、ユーザーとの対話を通じて基本設計を行う。技術選定が必要な判断ポイントでは `/adr_create` コマンドの実行をユーザーに提示し、別セッションでの実行を促す。最終的に `docs/project-definition/basic-design.md` を生成する。整合性チェックを経て品質を担保する。

## 使い方

```
/basic_design
```

引数なし。`docs/project-definition/architecture.md` と `docs/project-definition/requirements.md` を入力として読み込む。

## 出力先

- `docs/project-definition/basic-design.md`（固定パス）
- `docs/adr/`（技術選定ADR群、副産物）

## パス変数

- `{skill_dir}`: このファイルが存在するディレクトリの絶対パス
- `{arch_path}`: `docs/project-definition/architecture.md` の絶対パス
- `{req_path}`: `docs/project-definition/requirements.md` の絶対パス
- `{output_path}`: `docs/project-definition/basic-design.md` の絶対パス
- `{adr_dir}`: `docs/adr/` の絶対パス
- `{work_dir}`: `.skill_output/basic_design/` の絶対パス

## コンテキスト節約の原則

1. **参照ファイルは使用するPhaseでのみ読み込む**（先読みしない）
2. **大量コンテンツの生成はサブエージェントに委譲する**（Phase 2, Phase 3）
3. **サブエージェントからの返答は最小限にする**（詳細はファイルに保存させる）
4. **親コンテキストには要約・メタデータのみ保持する**
5. **サブエージェント間のデータ受け渡しはファイル経由で行う**（親を中継しない）
6. **技術選定は別セッションの `/adr_create` に委譲する**。本セッションはADRの結論部分（決定セクション + 受け入れたトレードオフ）のみ読み込む
7. **入力文書の全文を親コンテキストに保持しない**。Phase 0 で構造サマリのみ抽出し保持する

## 品質ゲート

| # | ゲート名 | 配置 | チェック内容 |
|---|---------|------|------------|
| QG-1 | 入力品質 | Phase 0 | architecture.md と requirements.md の存在・ステータス確認 |
| QG-2 | ADR整合性 | Phase 1（各ADR読込後） | 新ADRが既存の設計決定・他のADRと矛盾しないか |
| QG-3 | 整合性チェック | Phase 3 | 項目間整合性 + architecture.md / requirements.md との整合性 |

## ワークフロー

Phase 0（初期化・入力読込）→ 1（対話的設計）→ 2（文書生成）→ 3（整合性チェック）→ 4（出力・完了）

---

### Phase 0: 初期化・入力読込

```
## Phase 0: 初期化
```

**目的:** 入力ファイルの存在・構造を検証し、以降の Phase で使うメタデータを抽出する

#### Step 1: 入力ファイルの読み込みと検証

1. `{arch_path}` = `docs/project-definition/architecture.md` を設定する
2. `{req_path}` = `docs/project-definition/requirements.md` を設定する
3. `{output_path}` = `docs/project-definition/basic-design.md` を設定する
4. `{adr_dir}` = `docs/adr/` を設定する
5. `{work_dir}` = `.skill_output/basic_design/` を設定する
6. `{arch_path}` を Read する。不在の場合はエラー出力して終了:
   「`docs/project-definition/architecture.md` が見つかりません。先に `/arch_design` を実行してください」
7. `{req_path}` を Read する。不在の場合はエラー出力して終了:
   「`docs/project-definition/requirements.md` が見つかりません。先に `/requirement_define` を実行してください」

#### Step 2: 構造サマリの抽出

architecture.md から以下を抽出し、親コンテキストに保持する（全文は保持しない）:

- `{arch_style}`: アーキテクチャスタイル
- `{tech_stack}`: 技術スタックテーブル
- `{components}`: コンポーネント一覧（名前、責務、技術）
- `{cross_cutting}`: 横断的関心事（ログ・監視、エラーハンドリング等）

requirements.md から以下を抽出し、親コンテキストに保持する（全文は保持しない）:

- `{sr_list}`: 機能要件テーブル
- `{nfr_list}`: 非機能要件テーブル
- `{uc_list}`: ユースケース一覧テーブル（Must のみ）
- `{constraints}`: 制約一覧

#### Step 3: 既存ADRの確認

1. `{adr_dir}` を Glob で確認する
2. 既存ADRファイルがある場合は各ADRの「決定」セクションのみを抽出し `{existing_adrs}` に保持する
3. ない場合は `{existing_adrs}` = 空

#### Step 4: QG-1 入力品質ゲート

以下を検証する:

- architecture.md のステータスが `Draft` でないこと（`Draft` の場合: 「architecture.md がまだ Draft です。`/arch_design` で確定してから実行してください」と出力して終了）
- requirements.md のステータスが `Confirmed` であること（`Draft` の場合: 「requirements.md が Draft です。`/requirement_define` で確定してから実行してください」と出力して終了）

`Bash` で `mkdir -p {work_dir}` を実行する。

テキスト出力:
```
## Phase 0 完了
- アーキテクチャ: {arch_style}
- 技術スタック: {N}レイヤー
- コンポーネント: {N}個
- 既存ADR: {N}件

Phase 1（対話的設計）に進みます。
```

---

### Phase 1: 対話的設計

```
## Phase 1: 対話的設計
```

**目的:** ユーザーとの対話で4項目を順に設計し確定する。技術選定が必要な判断ポイントでは `/adr_create` コマンドの実行を促す

#### 項目1: アプリケーションライブラリ選定

Phase 0 の構造サマリ（`{tech_stack}`, `{components}`, `{nfr_list}`, `{cross_cutting}`）を基に、主要技術の周辺ライブラリを分析し提案する。

1. `{tech_stack}` の各レイヤーについて、追加で必要なライブラリカテゴリを特定する:
   - ORM / DBクライアント
   - バリデーション
   - 状態管理（フロントエンド）
   - CSSフレームワーク / スタイリング
   - テストフレームワーク / テストユーティリティ
   - 可観測性SDK（ログライブラリ、トレーシング/メトリクスSDK — `{cross_cutting}` の方針に基づく）
   - その他プロジェクト要件に応じたライブラリ
2. 各カテゴリについて、制約・NFRから候補を1-2提案する
3. 各提案に理由（NFR/制約との対応）とトレードオフを明示する
4. ADR要否を判断する: 制約から一意に決まる場合は不要、トレードオフ分析が必要な場合は要

テキスト出力:
```
### アプリケーションライブラリ選定

| カテゴリ | 提案 | 理由 | ADR要否 |
|---------|------|------|--------|
| {カテゴリ} | {ライブラリ名} | {理由} | {要/不要} |

修正があればお知らせください。問題なければ「ok」と回答してください。
```

- 承認: 次の項目へ
- 修正指示: 修正を反映して再提示

#### ADR提案パターン

ADR要の項目について、以下のパターンで `/adr_create` の実行を促す:

```
### 技術選定: {ライブラリカテゴリ名}

この判断は選択肢のトレードオフ分析が必要です。
以下のコマンドを**別セッション**で実行してください:

`/adr_create {ライブラリカテゴリ名}の選定。スコープ: {決定対象}。制約: {確定済み技術スタック・方針から導出した制約リスト}`

完了したら「完了」と回答してください。
```

**ADR不要の判断基準**: 制約やNFR、技術スタックの依存関係から選択肢が1つに絞られる場合、ADRは不要。AIが根拠を示して直接決定する。

#### ADR読込と整合性検証

ユーザーが「完了」と回答したら:

1. `{adr_dir}` を Glob で確認し、新しいADRファイルを特定する
2. ADRファイルの「決定」セクション と「受け入れたトレードオフ」セクションのみを Read する（全文は読み込まない）
3. **QG-2: ADR整合性ゲート** — 新ADRの決定内容が以下と矛盾しないか検証する:
   - 確定済みの技術スタック・アーキテクチャ方針
   - 他の確定済みADR
   - `{constraints}` の制約
   - 矛盾検出時はユーザーにテキスト出力する:
     「ADR '{ADR名}' の決定が '{矛盾対象}' と矛盾しています: {詳細}。どう解決しますか？」
4. 決定を `{tech_decisions}` に追加する

#### 項目2: プロジェクト規約

項目1の選定結果と `{cross_cutting}` を基に、プロジェクト全体の規約を提案する。

対象:
- 命名規則: DB（テーブル名・カラム名）、API（パス・フィールド名）、コード（変数・関数・ファイル名）、各々のケーススタイル
- エラーハンドリング形式: エラーオブジェクトの構造、エラーコード体系
- ログ出力規約: 構造化形式、必須フィールド、ログレベル使い分け
- 計装規約: 何をスパンにするか、メトリクス命名規則（可観測性が必要な場合のみ）
- テスト方針: テスト対象の基準、テストファイルの命名・配置
- 環境変数: 命名規則、`.env` / `.env.local` の使い分け方針

各規約について:
1. 選定したライブラリのデフォルト規約を確認する
2. デフォルトをそのまま採用するか、カスタマイズするかを提案する
3. カスタマイズする場合は理由を明示する

テキスト出力:
```
### プロジェクト規約

#### 命名規則

| 対象 | ルール | 例 |
|------|--------|-----|
| DBテーブル名 | {ルール} | {例} |
| DBカラム名 | {ルール} | {例} |
| APIパス | {ルール} | {例} |
| APIフィールド名 | {ルール} | {例} |
| 変数・関数名 | {ルール} | {例} |
| ファイル名 | {ルール} | {例} |
| 環境変数 | {ルール} | {例} |

#### エラーハンドリング形式

{エラーオブジェクト構造の定義}

#### ログ出力規約

{構造化形式、必須フィールド、レベル使い分け}

#### テスト方針

{テスト対象基準、ファイル命名・配置}

#### 環境変数管理

{.env構成方針}

修正があればお知らせください。問題なければ「ok」と回答してください。
```

- 承認: 次の項目へ
- 修正指示: 修正を反映して再提示

#### 項目3: ディレクトリ構造

項目1・2の結果と `{components}` を基に、プロジェクトのディレクトリレイアウトを提案する。

1. arch_design のコンポーネント構成をディレクトリにマッピングする
2. 選定したライブラリが要求するディレクトリ（例: Prisma → `prisma/`）を配置する
3. 項目2の命名規則に従ったディレクトリ命名を適用する
4. ファイルベースルーティングの場合、ページURLとの対応を明示する

テキスト出力:
```
### ディレクトリ構造

```
{2-3階層のツリー表記}
```

| ディレクトリ | 役割 | 対応コンポーネント |
|------------|------|------------------|
| {path} | {役割} | {コンポーネント名 or —} |

{ファイルベースルーティングの場合のみ}
#### ページURL対応

| URL | ディレクトリ | 概要 |
|-----|-----------|------|
| {URL} | {ディレクトリ} | {概要} |

修正があればお知らせください。問題なければ「ok」と回答してください。
```

- 承認: 次の項目へ
- 修正指示: 修正を反映して再提示

#### 項目4: APIエンドポイント設計

`{uc_list}`, `{sr_list}` を基に、初期スコープのAPIエンドポイントを設計する。

1. ユースケースからリソース（名詞）と操作（動詞）を導出する
2. RESTful なエンドポイント一覧を構成する
3. リソースの主要フィールドを定義する（概念データモデルを兼ねる）
4. 共通規約（エラーレスポンス形式、ページネーション方式）を定義する
5. 項目2の命名規則に従って命名する
6. 各エンドポイントの認証要否を `{cross_cutting}` のセキュリティ方針に基づき決定する

テキスト出力:
```
### APIエンドポイント設計

#### エンドポイント一覧

| メソッド | パス | 概要 | 認証 | 対応UC/SR |
|---------|------|------|------|----------|
| {METHOD} | {path} | {概要} | {要/不要} | {UC/SR-ID} |

#### リソース定義

##### {リソース名}

| フィールド | 概念型 | 説明 |
|-----------|--------|------|
| {field} | {type} | {description} |

{リソース間の関連}
- {リソースA} → {リソースB}: {関連の説明}

#### 共通規約

- エラーレスポンス形式: {定義}
- ページネーション: {方式}（該当する場合）

修正があればお知らせください。問題なければ「ok」と回答してください。
```

- 承認: Phase 1 完了サマリへ
- 修正指示: 修正を反映して再提示

#### Phase 1 完了サマリ

全項目を確定したら:

```
### Phase 1 サマリ

- ライブラリ: {N}カテゴリ（ADR {N}件）
- 規約: {N}項目
- ディレクトリ: {N}ディレクトリ
- APIエンドポイント: {N}件
- リソース: {N}個

修正があればお知らせください。問題なければ「ok」と回答してください。
```

- 承認: ファイル出力へ
- 修正指示: 修正を反映して再提示

#### Phase 1 確定情報のファイル出力

Phase 1 の全確定情報を `{work_dir}/design-decisions.md` に Write で保存する。以下のセクションを含む:

- ライブラリ選定結果（各カテゴリの選定ライブラリ + ADR参照 + 選定理由）
- プロジェクト規約（全規約の定義）
- ディレクトリ構造（ツリー + 役割テーブル + ページURL対応）
- APIエンドポイント設計（エンドポイント一覧 + リソース定義 + 共通規約）

テキスト出力:
```
## Phase 1 完了

Phase 2（文書生成）に進みます。
```

---

### Phase 2: 文書生成

```
## Phase 2: 文書生成
```

**目的:** Phase 1 で確定した全情報を統合し、`docs/project-definition/basic-design.md` を生成する

#### Step 1: 文書生成（サブエージェントに委譲）

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

```
`{skill_dir}/templates/generate-document.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{req_path}`: {req_path} の絶対パス
- `{arch_path}`: {arch_path} の絶対パス
- `{decisions_path}`: {work_dir}/design-decisions.md の絶対パス
- `{template_path}`: {skill_dir}/references/output-template.md の絶対パス
- `{adr_dir}`: {adr_dir} の絶対パス
- `{output_save_path}`: {output_path} の絶対パス
```

サブエージェントの返答: `result` + `sections_completed`

#### Step 2: ユーザー確認

1. `{output_path}` を Read し、ユーザーにテキスト出力する
2. 「修正があればお知らせください。問題なければ『ok』と回答してください。」
   - 修正指示あり: 内容を Edit で修正して再提示
   - 承認: Phase 3 へ

テキスト出力:
```
## Phase 2 完了
- 基本設計書: {output_path}

Phase 3（整合性チェック）に進みます。
```

---

### Phase 3: 整合性チェック

```
## Phase 3: 整合性チェック
```

**目的:** 項目間および上流文書との整合性を検証する

#### Step 0: 準備

1. `{check_loop}` = 0

#### Step 1: 整合性チェック実行

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

```
`{skill_dir}/templates/check-consistency.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{design_path}`: {output_path} の絶対パス
- `{arch_path}`: {arch_path} の絶対パス
- `{req_path}`: {req_path} の絶対パス
- `{adr_dir}`: {adr_dir} の絶対パス
- `{findings_save_path}`: {work_dir}/consistency-check.md の絶対パス
```

サブエージェントの返答: `verdict` + `issues` + `summary`

#### Step 2: 結果に応じた処理

**verdict: pass の場合**:
1. チェック結果サマリをユーザーにテキスト出力する
2. Phase 4 へ進む

**verdict: needs_revision の場合**:
1. 指摘一覧をユーザーにテキスト出力する
2. `{check_loop}` が 2 以上の場合:
   「整合性チェックで指摘が解消されませんでした。`{work_dir}/consistency-check.md` を確認し、手動で修正してから再実行してください」と出力し、スキル終了
3. Step 3 へ

#### Step 3: 修正

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

```
`{skill_dir}/templates/fix-document.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{design_path}`: {output_path} の絶対パス
- `{findings_path}`: {work_dir}/consistency-check.md の絶対パス
```

修正サマリをテキスト出力する。`{check_loop}` += 1。Step 1 に戻る（再チェック）。

---

### Phase 4: 出力・完了

```
## Phase 4: 完了
```

#### Step 1: クリーンアップ

`{work_dir}` 内の一時ファイルを削除する（Bash: `rm -rf {work_dir}`）。

#### Step 2: 完了出力

```
## basic_design 完了
- 入力: {arch_path}, {req_path}
- 出力: {output_path}
- ADR: {adr_dir} ({N}件)
- 整合性チェック: {check_loop + 1}ラウンド, verdict: pass

次のステップ:
1. `/process_design` で開発プロセス設計に進んでください
2. `/extract_decisions` で設計判断記録を生成してください
```
