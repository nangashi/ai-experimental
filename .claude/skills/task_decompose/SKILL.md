---
allowed-tools: Glob, Grep, Read, Write, Edit, Task
description: プロジェクト定義文書からグリーンフィールド初期実装のタスクリストを生成するスキル
disable-model-invocation: true
---

`docs/project-definition/` 配下の5文書（problem-statement.md, requirements.md, architecture.md, standards.md, development-process.md）を入力として、垂直スライスに基づくタスク分解を行い、各タスクの背景・やること・受け入れ基準・制約・スコープ外を含む構造化されたタスクリスト文書を生成する。

**適用条件**: (1) `docs/project-definition/` 配下の5文書が全て Confirmed であること (2) グリーンフィールド開発の初期実装タスク分解であること。既存プロジェクトへの機能追加、部分的な文書からの分解は対象外。

## 使い方

```
/task_decompose
```

引数なし。`docs/project-definition/` 配下の全文書を入力として読み込む。

## 出力先

- `docs/project-definition/task-list.md`（固定パス）

## パス変数

- `{skill_dir}`: このファイルが存在するディレクトリの絶対パス
- `{project_def_dir}`: `docs/project-definition/` の絶対パス
- `{output_path}`: `docs/project-definition/task-list.md` の絶対パス
- `{work_dir}`: `.skill_output/task_decompose/` の絶対パス
- `{ps_path}`: `docs/project-definition/problem-statement.md`
- `{req_path}`: `docs/project-definition/requirements.md`
- `{arch_path}`: `docs/project-definition/architecture.md`
- `{std_path}`: `docs/project-definition/standards.md`
- `{dp_path}`: `docs/project-definition/development-process.md`

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
| QG-1 | 網羅性・依存関係・規模 | Phase 1→2 境界 | サブエージェント(sonnet) | SR/NFR/IR/コンポーネントカバレッジ、依存サイクル、依存正当性、重複分析、タスク規模、NFRマッピング妥当性 |
| QG-2 | イシュー品質・整合性 | Phase 2→3 境界 | サブエージェント(sonnet) | 独立完結性、独立検証性、自己完結性、垂直スライス、境界明確性、制約充足性、タスク間整合性 |

## ワークフロー

Phase 0（初期化）→ 1（タスク分解）→ [QG-1（最大3回、needs_revision 時はタスクリスト修正のみ）] → [ユーザー確認] → 2（イシュー本文生成）→ [QG-2（最大3回、needs_revision 時はイシュー本文修正のみ）] → [ユーザー確認] → 3（出力・完了）

---

### Phase 0: 初期化

**目的**: 入力検証と構造情報の抽出

#### Step 1: 入力ファイルの読み込みと検証（QG-0）

1. パス変数の設定（`{skill_dir}`, `{project_def_dir}`, `{output_path}`, `{work_dir}`, `{ps_path}`, `{req_path}`, `{arch_path}`, `{std_path}`, `{dp_path}`）
2. `{work_dir}` ディレクトリの作成
3. 5ファイルを Read で読み込む。各ファイルについて:
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
- `{p2p3_handoff}`: P2/P3 への引き継ぎ事項

**standards.md から:**
- `{coding_conventions}`: コーディング規約サマリ（命名規則テーブル、エラーハンドリングパターン）
- `{quality_enforcement}`: 規約の自動強制サマリテーブル

**development-process.md から:**
- `{test_strategy}`: テスト戦略サマリ（投資配分、フレームワーク、カバレッジ）
- `{cicd_pipeline}`: CI/CD パイプライン構成テーブル
- `{quality_check_matrix}`: 品質チェック配置サマリテーブル

**problem-statement.md から:**
- `{problem_summary}`: 問題定義の要約（1-2文）
- `{approach}`: 採用アプローチ

#### Step 3: Phase 0 完了出力

```
### Phase 0 完了
- 入力ファイル: 5件（全て Confirmed）
- 機能要件: {N}件（SR-001〜SR-{N}）
- 非機能要件: {N}件
- インターフェース要件: {N}件
- コンポーネント: {N}件
- ユースケース: Must {N}件 / Nice {N}件

Phase 1（タスク分解）に進みます。
```

---

### Phase 1: タスク分解

**目的**: プロジェクト文書の構造情報に基づき、初期実装のタスクリストを生成する

#### Step 1: 分解ルールの適用

以下のルールを順に適用し、タスクを導出する:

**ルール1: 最初の垂直スライスの特定**
- 問い: 「最初にデプロイ可能な、エンドツーエンドで検証可能な成果物は何か？」
- 方法: `{components}` と `{component_deps}` から、全機能の前提となるインフラ・認証・デプロイ基盤を特定する
- スコープ境界: ルール1にはアプリケーションフレームワーク・認証・ホスティング設定のみを含める。DB接続・スキーマ構築は、それ自体がエンドツーエンドで検証可能なデータパスの一部としてルール2に含める
- 出力: Task 1（プロジェクト初期化 + 認証 + デプロイ）
- 検証基準の例: 「アプリがインターネット上で動作し、認証済みユーザーのみアクセスできる」

**ルール2: コアデータパスの特定**
- 問い: 「最初の完全なデータ読み書きサイクル（Create + Read）は何か？」
- 方法: `{sr_table}` からコアデータパスを構成する Create 系 SR と Read 系 SR のペアを特定する。`{uc_table}` の Must UC から主要データフローを判断し、そのフローに属する Create+Read ペアを選択する。`{traceability}` からそれに関わる全コンポーネントを抽出。DB接続・スキーマ・Repository・Service・Handler・UIコンポーネントの初回構築を1タスクにまとめる
- 複数エンティティがある場合の優先基準: 他エンティティから最も依存されるもの（被依存数が最大）を優先する。被依存数が同じ場合、`{uc_table}` の Must 優先度で最初に言及されるものを優先する
- 出力: Task 2（コアデータパスの実装）
- エラーハンドリング・バリデーションはコアデータパスの一部として含める（SR で同一フローに属するため）

**ルール3: 機能拡張の垂直スライス化**
- 問い: 「コアデータパスの上に、どの機能を独立した垂直スライスとして追加できるか？」
- 方法: 残りの SR を UC 境界でグルーピングする。各グループについて:
  - 既存コンポーネントへのメソッド追加 + UI拡張で完結するか → 1タスク
  - 新規コンポーネントの導入が必要か → QG-1 チェック8の基準（SR 6以上またはコンポーネント5以上）を超えると予測される場合は分割を検討する。分割後も垂直スライスの原則（エンドツーエンドで検証可能）を維持すること
- グルーピング基準:
  - 同一 UI 操作に属する SR はまとめる（例: 既読化 SR-006 + 未読戻し SR-007 + 削除 SR-008）
  - 独立した画面/フローを持つ SR は別タスクにする（例: 検索 SR-009）
- UC 紐づきの判定: `{sr_table}` のトレース元列を参照し、特定 UC に紐づく SR はルール3で扱う。トレース元が UC ではないもの（NFR、制約等）はルール4の対象
- 横断 SR の扱い: 複数 UC にまたがる SR は、その SR を最初に実装するタスク（主担当）にマッピングする。Step 3 の SR マッピング時に他タスクでの関与を注記する
- 出力: Task 3, 4, ...

**ルール4: 横断的関心事の分離**
- 問い: 「特定の UC に紐づかないが実装が必要な要素は何か？」
- 方法: `{p2p3_handoff}` と `{nfr_table}` から、UC に紐づかないインフラ・運用・セキュリティ要素を抽出。テーマごとにグルーピングする
- スコープ: `{sr_table}` のトレース元が特定 UC に紐づく SR はルール3 で扱い済み。ルール4 の対象はトレース元が UC ではない SR・NFR・P2/P3 引き継ぎ事項・インフラ設定に限定する
- 出力: 追加タスク群（PWA、運用基盤、セキュリティ等）

**ルール5: テスト・CI/CD の配置**
- テストタスクは、テスト対象となる全機能タスクに blocked_by を設定する。`{test_strategy}` のテスト投資配分に記載されたテスト種別・対象層に基づき、テスト対象となるタスクを特定する
- CI/CD はテストが存在することが前提 → テストタスクに依存
- 出力: テストタスク、CI/CD タスク

#### Step 2: 依存関係の設定

各タスクについて `blocked_by` を設定する:
- タスク A が タスク B の成果物（ファイル、コンポーネント、設定）を前提とする場合、A は B に依存する
- 依存は最小限にする（推移的依存は記録しない。A→B→C の場合、A の blocked_by に C は含めない）
- 依存関係に循環がないことを確認する

#### Step 3: SR/NFR/IR マッピング

各タスクに対して、そのタスクが実現する SR/NFR/IR の ID を記録する。
- 1つの SR が複数タスクにまたがる場合: 主担当タスクを明記し、他タスクでの関与内容を注記する
- NFR のマッピング: そのタスク単独で NFR を検証可能な場合のみ受け入れ基準に含める。横断的に検証すべき NFR（パフォーマンス目標等）はテスト・CI/CD タスクにマッピングし、機能タスクの受け入れ基準には含めない
- architecture.md の `{traceability}` テーブルを参考にする

#### Step 4: タスクリスト構造の保存

以下の形式で `{work_dir}/task-structure.md` に保存する:

```markdown
# タスクリスト構造

## サマリ
- タスク数: {N}
- SR カバレッジ: {M}/{total} (マッピング詳細は下記)
- NFR カバレッジ: {M}/{total}
- IR カバレッジ: {M}/{total}

## 依存関係グラフ
{テキストまたは mermaid}

## タスク一覧

### Task {N}: {タイトル}
- **スコープ**: {1-2文の概要}
- **SR**: {SR-ID リスト}
- **NFR**: {NFR-ID リスト}
- **IR**: {IR-ID リスト}
- **コンポーネント**: {関連コンポーネント名リスト}
- **blocked_by**: {依存タスク番号リスト} — {依存理由（例: Task 1 が提供する認証基盤が前提）}
- **受け入れ基準（概要）**: {1-2文}
```

#### Step 5: QG-1 実行

`Task`（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

```
`{skill_dir}/templates/check-coverage.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{task_structure_path}`: {work_dir}/task-structure.md
- `{req_path}`: {req_path}
- `{arch_path}`: {arch_path}
- `{findings_save_path}`: {work_dir}/qg1-result.md
```

**修正ループ**:
- サブエージェントの返答が `needs_revision` の場合:
  1. `{work_dir}/qg1-result.md` を Read でギャップリストを確認
  2. 親がタスクリスト構造（`{work_dir}/task-structure.md`）の対象箇所のみを修正（Phase 全体への差し戻しは行わない）
  3. 修正時は、追加した SR が既存タスクと重複しないことを確認してからタスクリストを更新する
  4. QG-1 サブエージェントを再実行
- 最大2回の修正。3回目も `needs_revision` の場合、残課題とその原因をユーザーに提示し、対応方針（手動割り当て / N/A としてスキップ / スキル中断して入力文書を修正）を確認する
- `pass with warnings` の場合はそのまま次へ進む（チェック8のフラグはユーザーチェックポイントで表示）

---

### ユーザーチェックポイント: タスクリスト構造の確認

QG-1 通過後、以下を提示:

```
### タスクリスト構造

| # | タイトル | SR数 | コンポーネント数 | blocked_by | 受け入れ基準（概要） |
|---|---------|------|----------------|------------|------------------|
| 1 | {タイトル} | {N} | {N} | — | {概要} |
| 2 | {タイトル} | {N} | {N} | 1 | {概要} |
| ... | | | | | |

### 依存関係グラフ
{図}

### カバレッジ
- SR: {M}/{N} ✓
- NFR: {M}/{N} ✓
- IR: {M}/{N} ✓
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

QG-2 通過後、全イシュー本文を提示し確認。以下の観点での確認を促す:
- 独立完結性: 単独のAI開発セッションで完了可能か
- 独立検証性: 受け入れ基準だけで合否判定が可能か
- 垂直スライス: エンドツーエンドの機能を提供するか
- 自己完結性: AI開発エージェントがこのイシュー本文だけで作業開始できるか

---

### Phase 3: 出力・完了

#### Step 1: タスクリスト文書の生成

`{skill_dir}/references/output-template.md` を Read でテンプレートを把握し、`{work_dir}/task-bodies.md` の全イシュー本文を統合して `{output_path}` に Write する。

#### Step 2: 完了出力

```
## task_decompose 完了
- 入力: {project_def_dir} (5ファイル)
- 出力: {output_path}
- タスク数: {N}
- カバレッジ: SR {M}/{N}, NFR {M}/{N}, IR {M}/{N}
- QG-1: pass (網羅性・依存関係・規模)
- QG-2: pass (イシュー品質・整合性)
```

#### Step 3: クリーンアップ

`{work_dir}` 内の一時ファイルを削除する。

---

## 具体例: リーディングリスト管理ツールでの適用

### Phase 0 で抽出される構造情報

- SR: 18件（SR-001〜SR-018）
- NFR: 6件（NFR-1〜NFR-6）
- IR: 3件（IR-001〜IR-003）
- コンポーネント: 9件（ArticleListPage, ArticleSaveForm, SearchPage, ArticleCard, ArticleService, ArticleRepository, WebShareTargetHandler, AuthGuard, TitleFetcher）
- UC: Must 10件 + Nice 6件

### Phase 1 での分解結果

**ルール1 適用（最初の垂直スライス）**:
- `{component_deps}` から AuthGuard が全コンポーネントの前提であることを特定
- DB接続はルール2に含めるため、ルール1はフレームワーク・認証・ホスティングに限定
- → Task 1: 認証付き Next.js アプリを Netlify にデプロイする

**ルール2 適用（コアデータパス）**:
- `{uc_table}` の Must UC から主要フローを判断: UC-1（保存）→ UC-2（閲覧）が主要データフロー
- `{sr_table}` から SR-001（保存）+ SR-004（未読一覧）が主要フローの Create+Read ペア
- Article が唯一の主要エンティティ（他エンティティなし）のため候補は1つ
- `{traceability}` から関連コンポーネント: ArticleSaveForm → ArticleService → TitleFetcher → ArticleRepository + ArticleListPage → ArticleCard
- DB接続、スキーマ、エラー型を含む初回構築
- SR-010（重複チェック）、SR-014/016（バリデーション）、SR-015（TitleFetcher失敗）は保存フローの一部として含める
- → Task 2: PC 経由で記事 URL を保存し未読一覧に表示する

**ルール3 適用（機能拡張）**:
- SR-006 + SR-007 + SR-008: `{sr_table}` トレース元が UC-3/UC-4/UC-5 に紐づく。同一 UI（ArticleCard のアクション）に属する → Task 3
- SR-018（既読一覧表示）: トレース元が UC-2 に紐づく。既読化操作と同じタスクに含め、既読化→既読一覧表示のフローを1タスクで検証可能にする → Task 3 に含める
- SR-009: トレース元が UC-7 に紐づく。独立画面（SearchPage）→ Task 4
- SR-017（デバイス間反映）: トレース元が複数 UC 横断。コアデータパス（Task 2）の DB 設計で実現済みとなるため、Task 2 を主担当としマッピング

**ルール4 適用（横断的関心事）**:
- SR-002 + IR-001: PWA / Web Share Target はプラットフォーム機能の新規導入 → Task 5
- SR-013 + NFR-3/4 + `{p2p3_handoff}`: トレース元が NFR・制約。警告・セキュリティ・運用基盤 → Task 6

**ルール5 適用（テスト・CI/CD）**:
- `{test_strategy}` のテスト投資配分: E2E テストは Handler 層〜DB 全体が対象
- テスト対象: Task 2（コアデータパス）, Task 3（既読管理）, Task 4（検索）, Task 5（PWA/Web Share Target）, Task 6（運用基盤）
- → Task 7（テスト）は Task 3, 4, 5, 6 に依存
- → Task 8（CI/CD）は Task 7 に依存

### 依存関係グラフ

```
Task 1 ← (none)
Task 2 ← Task 1  — Task 1 が提供する認証基盤・デプロイ環境が前提
Task 3 ← Task 2  — Task 2 が構築する ArticleService・ArticleRepository が前提
Task 4 ← Task 2  — Task 2 が構築する ArticleRepository・データスキーマが前提
Task 5 ← Task 2  — Task 2 が構築する ArticleService（保存フロー）が前提
Task 6 ← Task 2  — Task 2 が構築するアプリケーション基盤上に運用機能を追加
Task 7 ← Task 3, Task 4, Task 5, Task 6  — テスト対象の全機能タスクが完了していること
Task 8 ← Task 7  — CI で実行するテストが存在すること
```
