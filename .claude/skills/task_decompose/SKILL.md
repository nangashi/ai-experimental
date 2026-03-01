---
allowed-tools: Glob, Grep, Read, Write, Edit, Task
description: プロジェクト定義文書からグリーンフィールド初期実装のタスクリストを生成するスキル
disable-model-invocation: true
---

`docs/project-definition/` 配下の6文書（problem-statement.md, requirements.md, architecture.md, standards.md, development-process.md, detailed-design.md）を入力として、垂直スライスに基づくタスク分解を行い、各タスクの目的・受け入れ基準・入力（設計書参照）を含む構造化されたタスクリスト文書を生成する。

**適用条件**: (1) `docs/project-definition/` 配下の6文書が全て Confirmed であること (2) グリーンフィールド開発の初期実装タスク分解であること。既存プロジェクトへの機能追加、部分的な文書からの分解は対象外。

## 使い方

```
/task_decompose
```

引数なし。`docs/project-definition/` 配下の全文書を入力として読み込む。

## 出力先

- `docs/project-definition/task-list.md`（マスターファイル）
- `docs/project-definition/task-list/`（個別タスクファイル格納ディレクトリ）

## パス変数

- `{skill_dir}`: このファイルが存在するディレクトリの絶対パス
- `{project_def_dir}`: `docs/project-definition/` の絶対パス
- `{output_path}`: `docs/project-definition/task-list.md` の絶対パス
- `{output_dir}`: `docs/project-definition/task-list/`（個別タスクファイル格納ディレクトリ）
- `{work_dir}`: `.skill_output/task_decompose/` の絶対パス
- `{ps_path}`: `docs/project-definition/problem-statement.md`
- `{req_path}`: `docs/project-definition/requirements.md`
- `{arch_path}`: `docs/project-definition/architecture.md`
- `{std_path}`: `docs/project-definition/standards.md`
- `{dp_path}`: `docs/project-definition/development-process.md`
- `{dd_path}`: `docs/project-definition/detailed-design.md`

## コンテキスト管理方針

| 方針 | 適用箇所 |
|------|---------|
| 構造情報の抽出保持 | Phase 0 で各文書から構造情報（テーブル・リスト）を抽出し親コンテキストに保持。全文は保持しない |
| ファイル経由のデータ受渡し | Phase 1→QG-1 は `task-structure.md` 経由、Phase 2→QG-2 は `task-bodies.md` 経由 |
| サブエージェントへの入力最小化 | QG-2 には設計書を渡さない（自己完結性チェックの独立性確保） |

## 品質ゲート

| # | ゲート名 | 配置 | 実行者 | チェック内容 |
|---|---------|------|--------|------------|
| QG-0 | 入力品質 | Phase 0 | 親 | 全入力ファイルの存在・ステータス Confirmed |
| QG-1 | 網羅性・依存関係・規模 | Phase 1→2 境界 | サブエージェント(sonnet) | SR/NFR/IR/コンポーネント/プロセス成果物カバレッジ、依存サイクル、依存正当性、重複分析、タスク規模、NFRマッピング妥当性、PR凝集度 |
| QG-2 | イシュー品質・整合性 | Phase 2→3 境界 | サブエージェント(sonnet) | 独立完結性（PR基準）、独立検証性、自己完結性、検証可能性、ブロック記述の十分性、入力参照の具体性、タスク間整合性 |

## ワークフロー

Phase 0（初期化）→ 1（タスク分解: スライス特定 → PR分割）→ [QG-1] → [ユーザー確認] → 2（イシュー本文生成）→ [QG-2] → [ユーザー確認] → 3（出力・完了）

---

### Phase 0: 初期化

**目的**: 入力検証と構造情報の抽出

#### Step 1: 入力ファイルの読み込みと検証（QG-0）

1. パス変数の設定（`{skill_dir}`, `{project_def_dir}`, `{output_path}`, `{output_dir}`, `{work_dir}`, `{ps_path}`, `{req_path}`, `{arch_path}`, `{std_path}`, `{dp_path}`, `{dd_path}`）
2. `{work_dir}` ディレクトリの作成
3. 6ファイル（ps, req, arch, std, dp, dd）を Read で読み込む。各ファイルについて:
   - 不在 → エラー終了（先行スキルの実行を案内）
   - ステータスが Confirmed でない → エラー終了

#### Step 2: 構造情報の抽出

各文書から以下を抽出し親コンテキストに保持（全文は保持しない）:

**requirements.md から:**
- `{sr_table}`: 機能要件テーブル（SR-ID, 要件, EARS型, トレース元）
- `{nfr_table}`: 非機能要件テーブル（NFR-ID, 観点, 要件, 測定基準）
- `{ir_table}`: インターフェース要件テーブル（IR-ID, インターフェース, 要件, トレース元）
- `{uc_table}`: ユースケーステーブル（UC-ID, シナリオ, 優先度, 種別）
- `{constraints}`: 制約テーブル
- `{scope}`: スコープ（Must / Nice-to-have / スコープ外）

**architecture.md から:**
- `{tech_stack}`: 技術スタックテーブル
- `{components}`: コンポーネント一覧テーブル（コンポーネント, 責務, 技術, 関連SR）
- `{component_deps}`: コンポーネント間依存関係（mermaid記述またはテキスト要約）
- `{directory_structure}`: ディレクトリ構造とファイル配置
- `{data_schema}`: データスキーマ設計
- `{auth_design}`: 認証・アクセス制御設計
- `{error_handling}`: エラーハンドリング方針
- `{traceability}`: 要件トレーサビリティ（SR-ID→対応コンポーネント）
- `{external_service_setup}`: 外部サービスセットアップ要件テーブル（サービス名、用途、セットアップ内容、クレデンシャル、環境変数）。該当セクションがない場合は空
- `{p2p3_handoff}`: P2/P3 への引き継ぎ事項

**standards.md から:**
- `{coding_conventions}`: コーディング規約サマリ（命名規則テーブル、エラーハンドリングパターン）
- `{quality_enforcement}`: 規約の自動強制サマリテーブル

**development-process.md から:**
- `{test_strategy}`: テスト戦略サマリ（投資配分、フレームワーク、カバレッジ）
- `{cicd_pipeline}`: CI/CD パイプライン構成テーブル
- `{quality_check_matrix}`: 品質チェック配置サマリテーブル
- `{process_artifacts}`: 作成すべきドキュメント・設定ファイル一覧（ドキュメント戦略・開発環境設定等のセクションで明示的にリストされた成果物。例: README.md, CLAUDE.md, .env.example, .vscode/* 等。CI/CD パイプラインやテスト設定のように他の抽出変数で既にカバーされるものは除外する）

**problem-statement.md から:**
- `{problem_summary}`: 問題定義の要約（1-2文）
- `{approach}`: 採用アプローチ

**detailed-design.md から:**
- `{table_definitions}`: テーブル定義一覧（テーブル名、カラム、型、制約）
- `{service_methods}`: Service メソッド一覧（メソッド名、引数型、戻り値型、エラーケース）
- `{api_contracts}`: API 契約一覧（Server Action / Route Handler の仕様）
- `{type_catalog}`: 型定義カタログ（エンティティ型、DTO型、DI インターフェース、エラー型）
- `{batch_jobs}`: バッチジョブ定義（該当する場合）
- `{state_transitions}`: 状態遷移マトリクス（該当する場合）

#### Step 3: Phase 0 完了出力

```
### Phase 0 完了
- 入力ファイル: 6件（全て Confirmed）
- 機能要件: {N}件（SR-001〜SR-{N}）
- 非機能要件: {N}件
- インターフェース要件: {N}件
- コンポーネント: {N}件
- ユースケース: Must {N}件 / Nice {N}件
- プロセス成果物: {N}件

Phase 1（タスク分解）に進みます。
```

---

### Phase 1: タスク分解

**目的**: プロジェクト文書の構造情報に基づき、初期実装のタスクリストを生成する

#### Step 1: 分解ルールの適用

以下のルールを順に適用し、スライスを導出する:

**ルール0: ツールチェーンセットアップの分離**
- 問い: 「アプリケーションコードに先立ち、開発環境の品質基盤として配置すべきツール・設定は何か？」
- 方法: `{coding_conventions}`, `{quality_enforcement}`, `{directory_structure}` から、
  linter/formatter設定、TypeScript strict設定、エディタ設定を抽出する
- スコープ境界: アプリケーション固有のコード（next.config.js等）は含めない。
  純粋にツールチェーンの設定ファイルのみ
- 出力: 最初のタスク（ツールチェーンセットアップ）
- 検証基準の例: 「lint/formatコマンドが実行可能で、strict TypeScriptコンパイルが通る」

**ルール0.5: 外部サービスプロビジョニング**
- 問い: 「コード実装の前提として、外部サービスのWebコンソール上でのセットアップ（アカウント作成・プロジェクト作成・クレデンシャル取得）が必要なものは何か？」
- 方法: `{external_service_setup}` テーブルから外部サービスごとにタスクを生成する。`{external_service_setup}` が空の場合は、`{tech_stack}` と `standards.md` の環境変数テーブルを突合し、外部サービスのクレデンシャルが必要な環境変数を特定する
- スコープ境界: LLMが実行不可能な外部Webコンソール操作のみ。コード上の設定（auth.ts, drizzle.config.ts等）は含めない。複数サービスのセットアップを1タスクにまとめる（サービス数が3以下の場合）か、サービスごとに分割する（4以上の場合）
- 出力: 人間作業タスク（`executor: human`）
- 受け入れ基準の記述方針: 人間の作業完了をLLMが検証可能な条件で記述する（例: 「`.env.local` に `DATABASE_URL` が設定されており、接続テストが成功すること」「`.env.local` に `GOOGLE_CLIENT_ID` と `GOOGLE_CLIENT_SECRET` が設定されていること」）
- 検証基準の例: 「全ての外部サービスクレデンシャルが `.env.local` に設定され、依存するコード実装タスクの前提条件が満たされている」

**ルール1: 最初の垂直スライスの特定**
- 問い: 「最初にデプロイ可能な、エンドツーエンドで検証可能な成果物は何か？」
- 方法: `{components}` と `{component_deps}` から、全機能の前提となるインフラ・認証・デプロイ基盤を特定する
- スコープ境界: ルール1にはアプリケーションフレームワーク・認証・ホスティング設定のみを含める。DB接続・スキーマ構築は、それ自体がエンドツーエンドで検証可能なデータパスの一部としてルール2に含める。ツールチェーン設定（linter/formatter、TypeScript strict設定、エディタ設定）はルール0で分離済み
- 出力: スライス（プロジェクト初期化 + 認証 + デプロイ）
- 検証基準の例: 「アプリがインターネット上で動作し、認証済みユーザーのみアクセスできる」

**ルール2: コアデータパスの特定**
- 問い: 「最初の完全なデータ読み書きサイクル（Create + Read）は何か？」
- 方法: `{sr_table}` からコアデータパスを構成する Create 系 SR と Read 系 SR のペアを特定する。`{uc_table}` の Must UC から主要データフローを判断し、そのフローに属する Create+Read ペアを選択する。`{traceability}` からそれに関わる全コンポーネントを抽出。DB接続・スキーマ・Repository・Service・Handler・UIコンポーネントの初回構築を1スライスにまとめる
- 注記: コアデータパスの DB スキーマ構築ステップでは `{table_definitions}` の具体的なテーブル定義を参照する
- 複数エンティティがある場合の優先基準: 他エンティティから最も依存されるもの（被依存数が最大）を優先する。被依存数が同じ場合、`{uc_table}` の Must 優先度で最初に言及されるものを優先する
- 出力: スライス（コアデータパスの実装）
- エラーハンドリング・バリデーションはコアデータパスの一部として含める（SR で同一フローに属するため）

**ルール3: 機能拡張の垂直スライス化**
- 問い: 「コアデータパスの上に、どの機能を独立した垂直スライスとして追加できるか？」
- 方法: 残りの SR を UC 境界でグルーピングする。各グループについて:
  - 既存コンポーネントへのメソッド追加 + UI拡張で完結するか → 1スライス
  - 新規コンポーネントの導入が必要か → スライスとして特定する（規模の調整はStep 2で行う）
- 注記: 各機能拡張スライスのスコープは `{api_contracts}` を参照し Server Action / Route Handler 単位で特定する
- グルーピング基準:
  - 同一 UI 操作に属する SR はまとめる（例: 既読化 SR-006 + 未読戻し SR-007 + 削除 SR-008）
  - 独立した画面/フローを持つ SR は別スライスにする（例: 検索 SR-009）
- UC 紐づきの判定: `{sr_table}` のトレース元列を参照し、特定 UC に紐づく SR はルール3で扱う。トレース元が UC ではないもの（NFR、制約等）はルール4の対象
- 横断 SR の扱い: 複数 UC にまたがる SR は、その SR を最初に実装するタスク（主担当）にマッピングする。Step 4 の SR マッピング時に他タスクでの関与を注記する
- 出力: 追加スライス群

**ルール4: 横断的関心事の分離**
- 問い: 「特定の UC に紐づかないが実装が必要な要素は何か？」
- 方法: `{p2p3_handoff}` と `{nfr_table}` から、UC に紐づかないインフラ・運用・セキュリティ要素を抽出。テーマごとにグルーピングする
- スコープ: `{sr_table}` のトレース元が特定 UC に紐づく SR はルール3 で扱い済み。ルール4 の対象はトレース元が UC ではない SR・NFR・P2/P3 引き継ぎ事項・インフラ設定に限定する
- 出力: 追加タスク群（PWA、運用基盤、セキュリティ等）

#### Step 2: PR分割

ルール0〜4で特定した各スライスを、PRレビュー可能な単位に分割する。

以下のヒューリスティクスを各スライスに順に適用する:

**ヒューリスティクス1: レイヤー境界分割**
- スライスが複数のアーキテクチャレイヤー（DB/Repository/Service/API/UI）に
  またがる場合、レイヤー境界でタスクを分割する
- 分割後の各タスクは、そのレイヤー内で完結した検証が可能であること

**ヒューリスティクス2: 関心事の凝集度**
- 1つのタスク内の変更が単一の関心事（single concern）に属するか確認する
- 異なる関心事が混在する場合、関心事ごとにタスクを分割する
- 例: 認証設定とデプロイ設定は異なる関心事

**ヒューリスティクス3: 分割不要条件**
- 以下の全てに該当するスライスは分割しない:
  - 新規・変更ファイル推定 8 以下
  - 単一の関心事で完結する
- executor が `human` のタスク（コード変更を含まないため分割判断の対象外）

**テスト同梱の原則**:
- 各タスクに、そのタスクの受け入れ基準を検証するテストを含める
- テストだけの独立タスクは作らない
- `{test_strategy}` のテスト投資配分に基づき、各タスクに含めるテスト種別を判断する
- テストフレームワークのセットアップ（設定ファイル作成等）は、そのフレームワークを
  最初に使うタスクに含める

分割後、全タスクを通し番号で再採番する（3桁ゼロパディング: 001, 002, ...）。

#### Step 3: 依存関係の設定

各タスクについて `blocked_by` を設定する:
- タスク A が タスク B の成果物（ファイル、コンポーネント、設定）を前提とする場合、A は B に依存する
- 依存は最小限にする（推移的依存は記録しない。A→B→C の場合、A の blocked_by に C は含めない）
- 依存関係に循環がないことを確認する
- CI/CD タスクはテスト同梱タスクの最初の1つが完了した時点で着手可能とする

#### Step 4: SR/NFR/IR マッピング

各タスクに対して、そのタスクが実現する SR/NFR/IR の ID を記録する。
- 1つの SR が複数タスクにまたがる場合: 主担当タスクを明記し、他タスクでの関与内容を注記する
- NFR のマッピング: そのタスク単独で NFR を検証可能な場合のみ受け入れ基準に含める。横断的に検証すべき NFR（パフォーマンス目標等）は、その NFR を検証する E2E テストを含むタスクまたは CI/CD タスクにマッピングする。複数タスクに分散する場合は、最も代表的なシナリオを持つタスクを主担当とする
- architecture.md の `{traceability}` テーブルを参考にする
- プロセス成果物のマッピング: `{process_artifacts}` の各成果物がいずれかのタスクの「やること」に含まれることを確認する。含まれない成果物は最も適切なタスクに追加する:
  - ツールチェーン成果物（.vscode/* 等）→ ルール0のタスク
  - プロジェクト初期化時に必要な成果物（README.md, CLAUDE.md, .env.example 等）→ ルール1のタスク
  - 運用開始前に必要な成果物 → ルール4のタスク
  - CI/CD 関連の成果物 → CI/CD タスク

#### Step 5: タスクリスト構造の保存

以下の形式で `{work_dir}/task-structure.md` に保存する:

```markdown
# タスクリスト構造

## サマリ
- タスク数: {N}
- SR カバレッジ: {M}/{total} (マッピング詳細は下記)
- NFR カバレッジ: {M}/{total}
- IR カバレッジ: {M}/{total}
- プロセス成果物カバレッジ: {M}/{total}

## プロセス成果物マッピング

| 成果物 | 担当タスク |
|--------|----------|
| README.md | Task {NNN} |
| CLAUDE.md | Task {NNN} |
| ... | ... |

## 依存関係グラフ
{テキストまたは mermaid}

## タスク一覧

### Task 001: {タイトル}
- **元スライス**: ルール{N} — {スライス名}
- **executor**: {llm / human}
- **分割理由**: {適用したヒューリスティクス / "分割なし"}
- **スコープ**: {1-2文の概要}
- **SR**: {SR-ID リスト}
- **NFR**: {NFR-ID リスト}
- **IR**: {IR-ID リスト}
- **コンポーネント**: {関連コンポーネント名リスト}
- **blocked_by**: {依存タスク番号リスト} — {依存理由（例: Task 001 が提供する認証基盤が前提）}
- **受け入れ基準（概要）**: {1-2文}
```

#### Step 6: QG-1 実行

`Task`（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

```
`{skill_dir}/templates/check-coverage.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{task_structure_path}`: {work_dir}/task-structure.md
- `{req_path}`: {req_path}
- `{arch_path}`: {arch_path}
- `{dd_path}`: {dd_path}
- `{dp_path}`: {dp_path}
- `{findings_save_path}`: {work_dir}/qg1-result.md
```

**修正ループ**:
- サブエージェントの返答が `needs_revision` の場合:
  1. `{work_dir}/qg1-result.md` を Read でギャップリストを確認
  2. 親がタスクリスト構造（`{work_dir}/task-structure.md`）の対象箇所のみを修正（Phase 全体への差し戻しは行わない）
  3. 修正時は、追加した SR が既存タスクと重複しないことを確認してからタスクリストを更新する
  4. QG-1 サブエージェントを再実行
- 最大2回の修正。3回目も `needs_revision` の場合、残課題とその原因をユーザーに提示し、対応方針（手動割り当て / N/A としてスキップ / スキル中断して入力文書を修正）を確認する
- `pass with warnings` の場合はそのまま次へ進む（チェック8/13のフラグはユーザーチェックポイントで表示）

---

### ユーザーチェックポイント: タスクリスト構造の確認

QG-1 通過後、以下を提示:

```
### タスクリスト構造

| # | タイトル | 元スライス | SR数 | blocked_by | 受け入れ基準（概要） |
|---|---------|-----------|------|------------|------------------|
| 001 | {タイトル} | ルール{N} — {スライス名} | {N} | — | {概要} |
| 002 | {タイトル} | ルール{N} — {スライス名} | {N} | 001 | {概要} |
| ... | | | | | |

### 依存関係グラフ
{図}

### カバレッジ
- SR: {M}/{N} ✓
- NFR: {M}/{N} ✓
- IR: {M}/{N} ✓
- プロセス成果物: {M}/{N} ✓
- コンポーネント: {M}/{N} ✓

{QG-1 warnings があれば表示}

修正があればお知らせください。問題なければ「ok」と回答してください。
```

---

### Phase 2: イシュー本文生成

**目的**: 各タスクの構造化された本文を生成する

#### Step 1: 本文生成（サブエージェント）

`Task`（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

```
`{skill_dir}/templates/generate-task-bodies.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{task_structure_path}`: {work_dir}/task-structure.md
- `{ps_path}`: {ps_path}
- `{req_path}`: {req_path}
- `{arch_path}`: {arch_path}
- `{std_path}`: {std_path}
- `{dp_path}`: {dp_path}
- `{dd_path}`: {dd_path}
- `{output_save_path}`: {work_dir}/task-bodies.md
```

#### Step 2: QG-2 実行

`Task`（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

```
`{skill_dir}/templates/check-quality.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{task_bodies_path}`: {work_dir}/task-bodies.md
- `{task_structure_path}`: {work_dir}/task-structure.md
- `{qg1_result_path}`: {work_dir}/qg1-result.md
- `{findings_save_path}`: {work_dir}/qg2-result.md
```

**修正ループ**:
- サブエージェントの返答が `needs_revision` の場合:
  1. `{work_dir}/qg2-result.md` を Read で指摘リストを確認
  2. 親がイシュー本文（`{work_dir}/task-bodies.md`）の対象箇所のみを修正（Phase 全体への差し戻しは行わない）
  3. QG-2 サブエージェントを再実行
- 最大2回の修正。3回目も `needs_revision` の場合、残課題とその原因をユーザーに提示し、対応方針（手動修正 / 許容してスキップ / スキル中断）を確認する

---

### ユーザーチェックポイント: イシュー本文の確認

QG-2 通過後、サマリテーブルと先頭3件のサンプルを提示し確認する:

```
### イシュー本文サマリ

| # | タイトル | 受け入れ基準数 | 入力参照数 |
|---|---------|-------------|----------|
| 001 | {タイトル} | {N} | {N} |
| 002 | {タイトル} | {N} | {N} |
| ... | | | |

### サンプル（先頭3件）

{Task 001〜003 の全文}

---

以下の観点での確認をお願いします:
- 独立完結性: 1つのPRとしてレビュー・マージ可能か
- 独立検証性: 受け入れ基準だけで合否判定が可能か
- 検証可能性: スコープ内で独立に検証可能か
- 自己完結性: Issue本文と入力セクションの参照先で作業開始できるか

追加で確認したいタスクがあれば番号を指定してください。
問題なければ「ok」と回答してください。
```

---

### Phase 3: 出力・完了

#### Step 1: 出力ディレクトリの作成

`{output_dir}` ディレクトリを作成する（既存の場合は中身を削除する）。

#### Step 2: 個別タスクファイルの生成

`{work_dir}/task-bodies.md` の各タスク本文を個別ファイルとして `{output_dir}/{NNN}-{slug}.md` に Write する。
- slug: タスクの主要な内容を英語で短縮した名前（例: toolchain-setup, auth-config）

#### Step 3: マスターファイルの生成

`{skill_dir}/references/output-template.md` を Read でテンプレートを把握し、`{output_path}` にサマリ+依存グラフ+タスクリンクテーブルを Write する。

#### Step 4: 完了出力

```
## task_decompose 完了
- 入力: {project_def_dir} (6ファイル)
- 出力: {output_path}（マスター）+ {output_dir}（個別タスク {N}件）
- タスク数: {N}
- カバレッジ: SR {M}/{N}, NFR {M}/{N}, IR {M}/{N}
- QG-1: pass (網羅性・依存関係・規模)
- QG-2: pass (イシュー品質・整合性)
```

#### Step 5: クリーンアップ

`{work_dir}` 内の一時ファイルを削除する。

---

## 具体例: リーディングリスト管理ツールでの適用

### Phase 0 で抽出される構造情報

- SR: 18件（SR-001〜SR-018）
- NFR: 6件（NFR-1〜NFR-6）
- IR: 3件（IR-001〜IR-003）
- コンポーネント: 9件（ArticleListPage, ArticleSaveForm, SearchPage, ArticleCard, ArticleService, ArticleRepository, WebShareTargetHandler, AuthGuard, TitleFetcher）
- UC: Must 10件 + Nice 6件
- プロセス成果物: 3件（README.md, CLAUDE.md, .env.example）

### Phase 1 での分解結果

**ルール0 適用（ツールチェーンセットアップ）**:
- `{coding_conventions}` と `{quality_enforcement}` から linter/formatter 設定、TypeScript strict 設定、エディタ設定を抽出
- → 001: ツールチェーンセットアップ（biome, tsconfig strict, .vscode/*）

**ルール0.5 適用（外部サービスプロビジョニング）**:
- `{external_service_setup}` から Neon PostgreSQL（DATABASE_URL）、Google OAuth（GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET）、Netlify（サイト作成）を特定
- サービス数3 → 1タスクにまとめる
- → 002: 外部サービスセットアップ（executor: human）
  - Neon: アカウント作成・プロジェクト作成・DATABASE_URL取得
  - Google Cloud: プロジェクト作成・OAuthクライアント登録・リダイレクトURI設定・Client ID/Secret取得
  - Netlify: アカウント作成・サイト作成・GitHub連携

**ルール1 適用（最初の垂直スライス）→ ヒューリスティクス2（関心事分離）で3分割**:
- `{component_deps}` から AuthGuard が全コンポーネントの前提であることを特定
- DB接続はルール2に含めるため、ルール1はフレームワーク・認証・ホスティングに限定
- ツールチェーンはルール0で分離済み
- プロセス成果物マッピング: README.md → 003, CLAUDE.md → 003, .env.example → 003
- ヒューリスティクス2 適用: プロジェクト初期化・認証設定・デプロイ設定は異なる関心事 → 3タスクに分割
- → 003: Next.jsプロジェクト初期化 + ドキュメント（README, CLAUDE.md, .env.example）
- → 004: Auth.js認証設定（Google OAuth, ALLOWED_EMAIL, middleware）
- → 005: Netlifyデプロイ設定

**ルール2 適用（コアデータパス）→ ヒューリスティクス1（レイヤー境界分割）で5分割**:
- `{uc_table}` の Must UC から主要フローを判断: UC-1（保存）→ UC-2（閲覧）が主要データフロー
- `{sr_table}` から SR-001（保存）+ SR-004（未読一覧）が主要フローの Create+Read ペア
- `{traceability}` から関連コンポーネント: ArticleSaveForm → ArticleService → TitleFetcher → ArticleRepository + ArticleListPage → ArticleCard
- ヒューリスティクス1 適用: DB/Repository/Service/API/UI の5レイヤーに分割
- → 006: DB接続 + スキーマ + マイグレーション
- → 007: ArticleRepository + Integrationテスト（Vitestセットアップ含む）
- → 008: ArticleService + TitleFetcher + DI + Unitテスト
- → 009: 記事保存・一覧取得 Server Actions
- → 010: ArticleSaveForm + ArticleListPage + ArticleCard UI + E2Eテスト（Playwrightセットアップ含む）

**ルール3 適用（機能拡張）**:
- SR-006 + SR-007 + SR-008: 同一 UI（ArticleCard のアクション）に属する → 1スライス
- SR-018（既読一覧表示）: 既読化操作と同じスライスに含める
- → 011: 既読化・未読戻し・削除 Server Actions + 既読一覧取得
- → 012: ArticleCardActions UI + 既読一覧タブ + E2Eテスト
- SR-009: 独立画面（SearchPage）
- → 013: searchArticles Server Action + SearchPage + E2Eテスト

**ルール4 適用（横断的関心事）→ ヒューリスティクス2（関心事分離）で分割**:
- SR-002 + IR-001: PWA / Web Share Target → 関心事分離で2タスク
- → 014: PWA manifest + ServiceWorker
- → 015: Web Share Target Route Handler + テスト
- SR-013 + NFR-3/4 + `{p2p3_handoff}`: セキュリティ・運用基盤 → 関心事分離で3タスク
- → 016: HTTPセキュリティヘッダー + Error Boundary
- → 017: warm-up ping エンドポイント + テスト
- → 018: gitleaks + lefthook + Dependabot + pg_dump手順README記載

**CI/CD**:
- → 019: GitHub Actions CIパイプライン

### 依存関係グラフ

```
001 ← (none)
002 ← (none) [executor: human]
003 ← 001
004 ← 002, 003
005 ← 004
006 ← 002, 003
007 ← 006
008 ← 007
009 ← 008
010 ← 009
011 ← 008
012 ← 010, 011
013 ← 010
014 ← 003
015 ← 008, 014
016 ← 003
017 ← 006
018 ← 003
019 ← 007
```
