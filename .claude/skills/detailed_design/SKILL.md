---
allowed-tools: Glob, Grep, Read, Write, Edit, Task
description: アーキテクチャ設計書・開発規約書・開発プロセス設計書から詳細設計書を生成するスキル
disable-model-invocation: true
---

要件定義書・アーキテクチャ設計書・開発規約書・開発プロセス設計書を入力として、設計領域カタログの4グループを依存順に議論し、具体的なDB定義・サービスコントラクト・APIインターフェース・バッチ処理仕様を確定する。上流文書の設計方針から仕様を導出し、ユーザーの確認を経て `docs/project-definition/detailed-design.md` を生成する。整合性チェックを経て品質を担保する。

## 使い方

```
/detailed_design
```

引数なし。

## 出力先

- `docs/project-definition/detailed-design.md`（固定パス）

## パス変数

- `{skill_dir}`: このファイルが存在するディレクトリの絶対パス
- `{req_path}`: `docs/project-definition/requirements.md`
- `{arch_path}`: `docs/project-definition/architecture.md`
- `{std_path}`: `docs/project-definition/standards.md`
- `{dp_path}`: `docs/project-definition/development-process.md`
- `{output_path}`: `docs/project-definition/detailed-design.md`
- `{work_dir}`: `.skill_output/detailed_design/`

## コンテキスト管理方針

| 方針 | 適用箇所 |
|------|---------|
| 遅延読み込み | 各入力文書は Phase 0 で構造サマリのみ抽出。design-catalog.md は Phase 1 のグループ議論開始時に読込 |
| 親コンテキスト最小化 | Phase 2/3 のコンテンツ生成・整合性チェックはサブエージェントに委譲。親には要約のみ返す |
| ファイル経由のデータ受渡し | Phase 1→2 は design-decisions.md 経由。Phase 3 のチェック結果はファイル保存 |
| リセットポイント | Phase 1→2 の境界（全設計を design-decisions.md に統合し、Phase 2 はファイルのみ参照） |

## 品質ゲート

| # | ゲート名 | 配置 | チェック内容 |
|---|---------|------|------------|
| QG-0 | 入力品質 | Phase 0 Step 1 | 4ファイルの存在・Confirmed ステータス |
| QG-1 | 導出完全性 | Phase 1 完了前 | 全エンティティにテーブル定義、全Serviceコンポーネントにメソッド定義、全Handlerコンポーネントに API 契約、全 SR が少なくとも1仕様にトレース |
| QG-1b | グループ間整合性 | Phase 1 完了前（QG-1後） | DB型↔Service引数/戻り値の整合、Service↔API契約の整合、エラー型の層間一貫性、DI インターフェース↔実装の整合 |
| QG-2 | トレーサビリティ | Phase 2 Step 2 | SR/NFR/IR の全IDが詳細設計書のトレーサビリティセクションに出現 |
| QG-3 | 整合性チェック | Phase 3 | 内部整合性 + architecture.md / standards.md / requirements.md との整合性 |

## ワークフロー

Phase 0（初期化）→ 1（対話的詳細設計）→ 2（詳細設計書生成）→ 3（整合性チェック）→ 4（出力・完了）

---

### Phase 0: 初期化

**目的**: 入力の検証、コンテキスト抽出、議論スコープの確認

#### Step 1: 入力ファイルの読み込みと検証（QG-0）

1. パス変数の設定（`{skill_dir}`, `{req_path}`, `{arch_path}`, `{std_path}`, `{dp_path}`, `{output_path}`, `{work_dir}`）
2. 4ファイルを Read。各ファイル:
   - 不在 → エラー終了（先行スキルの実行を案内）
   - ステータスが Confirmed でない → エラー終了

#### Step 2: 構造サマリの抽出

各文書から以下を抽出し親コンテキストに保持（全文は保持しない）:

**requirements.md から:**
- `{sr_table}`: 機能要件テーブル
- `{nfr_table}`: 非機能要件テーブル
- `{ir_table}`: インターフェース要件テーブル

**architecture.md から:**
- `{tech_stack}`: 技術スタックテーブル
- `{components}`: コンポーネント一覧テーブル（名前、責務、技術、関連SR）
- `{component_deps}`: コンポーネント間依存関係
- `{data_schema}`: データスキーマ設計（エンティティ概要、スキーマ設計方針）
- `{auth_design}`: 認証・アクセス制御設計
- `{error_handling}`: エラーハンドリング方針（AppError 種別等）
- `{di_design}`: DI 設計方針
- `{directory_structure}`: ディレクトリ構造
- `{traceability}`: 要件トレーサビリティ（SR→コンポーネント）

**standards.md から:**
- `{naming_conventions}`: 命名規則テーブル
- `{schema_design_policy}`: スキーマ設計方針（正規化、命名規約）
- `{validation_strategy}`: バリデーション戦略マトリクス
- `{error_handling_patterns}`: エラーハンドリングパターン
- `{transaction_policy}`: トランザクション管理方針

**development-process.md から:**
- `{migration_strategy}`: マイグレーション戦略（ツール、実行タイミング）
- `{test_strategy}`: テスト戦略サマリ

#### Step 3: 導出スコープの検出

抽出した構造情報から、詳細設計の対象を自動検出:

- **エンティティ一覧**: `{data_schema}` のエンティティ概要から導出
- **Service 一覧**: `{components}` から Service 層コンポーネントを抽出
- **Handler 一覧**: `{components}` から Handler 層コンポーネントを抽出
- **バッチ処理の有無**: `{components}` にスケジュールジョブ・非同期処理コンポーネントがあるか
- **状態遷移の有無**: `{data_schema}` にステータス/状態カラムがあるか

#### Step 4: Phase 0 完了サマリと議論スコープの確認

```
### Phase 0 完了
- 入力: {4ファイルパス}
- 技術スタック: {サマリ}
- エンティティ: {N}個（{名前リスト}）
- Service コンポーネント: {N}個（{名前リスト}）
- Handler コンポーネント: {N}個（{名前リスト}）

### 議論スコープ

| # | グループ | 対象数 | 含める |
|---|---------|-------|--------|
| 1 | データベース設計 | エンティティ{N}個 | ✓ |
| 2 | サービス層設計 | Service{N}個 | ✓ |
| 3 | API インターフェース設計 | Handler{N}個 | ✓ |
| 4 | バッチ処理・非同期処理設計 | {N}個 | {✓ or 該当なし} |

付加: 型定義カタログ（Group 1-3 から自動合成）
付加: 状態遷移設計（{✓ Group 1-3 に統合 or 該当なし}）

修正があればお知らせください。問題なければ「ok」と回答してください。
```

`Bash` で `mkdir -p {work_dir}` を実行。承認後 `{work_dir}/scope-plan.md` に保存。

---

### Phase 1: 対話的詳細設計

**目的**: 上流文書から具体的仕様を導出し、ユーザーの確認を経て確定する

#### P1/P2/P3 との対話パターンの違い

- P1/P2/P3: 「選択肢を提示し、ユーザーが選ぶ」パターン。ADR 委譲が頻繁に発生
- detailed_design: 「上流文書から仕様を導出し、ユーザーが確認/修正する」パターン。ADR 委譲なし

#### グループ議論のフロー

含まれるグループを依存順（1 → 2 → 3 → 4）に以下のパターンで議論する:

##### 1. 仕様の導出と提示

`{skill_dir}/references/design-catalog.md` から当該グループの設計項目を参照し、上流文書の構造情報を用いて具体的仕様を導出する。導出した仕様を、各項目の導出元（SR-ID、architecture.md セクション番号等）を明記して提示する。

##### 2. ユーザー確認

```
修正があればお知らせください。問題なければ「ok」と回答してください。
```

##### 3. グループサマリと確認

グループ内の全項目を議論後、グループ設計サマリを提示:

```
### {グループ名} サマリ

| # | 項目 | 仕様内容 | 導出元 |
|---|------|---------|--------|
| 1 | {項目名} | {確定した仕様の要約} | {SR-xxx, architecture.md §x.x} |
| ... | | | |

修正があればお知らせください。問題なければ「ok」と回答してください。
```

#### Group 1: データベース設計

`{data_schema}` のエンティティ概要 + `{schema_design_policy}` + `{sr_table}` から以下を導出:

- **テーブル定義**: エンティティごとにカラム名、型、制約、デフォルト値、導出元を表形式で提示
- **Enum 定義**: ステータスカラム等がある場合、Enum 名と値を提示
- **リレーション**: 外部キー、カーディナリティ、ON DELETE/UPDATE
- **インデックス設計**: `{data_schema}` のインデックス方針 + `{sr_table}` のアクセスパターンから導出
- **マイグレーション計画**: `{migration_strategy}` のツール情報を踏まえ、初期マイグレーションファイルの分割粒度と命名を提示
- **状態遷移（該当時）**: ステータスカラムがある場合、有効な状態一覧と初期状態を提示

#### Group 2: サービス層設計

`{components}` の Service コンポーネント + `{traceability}` + `{sr_table}` から以下を導出:

- **メソッド一覧**: Service ごとにメソッド名、引数型、戻り値型、エラーケース、関連SR を表形式で提示
- **ビジネスルール仕様**: メソッドごとに具体的な判定条件・処理分岐を記述
- **トランザクション境界**: `{transaction_policy}` を踏まえ、トランザクション管理が必要な操作を特定
- **DI インターフェース定義**: `{di_design}` から抽象化境界を特定し、インターフェース定義（メソッドシグネチャ）を提示
- **ファクトリ関数設計**: Handler → Service の依存注入ポイントを提示
- **状態遷移（該当時）**: 有効な遷移ルール、ガード条件、副作用を提示

#### Group 3: API インターフェース設計

`{components}` の Handler コンポーネント + `{ir_table}` + `{sr_table}` + `{validation_strategy}` から以下を導出:

- **Server Action 定義**: アクション名、トリガー元、入力スキーマ（Zod 仕様）、出力型、バリデーション、認証要否、エラーレスポンス、関連SR
- **Route Handler 定義**: HTTPメソッド、パス、リクエスト/レスポンス形式、ステータスコード、認証/CSRF、関連IR
- **Server Component データ契約**: コンポーネント名、受け取るデータ形状、ソースとなる Service メソッド、関連SR
- **状態遷移（該当時）**: 遷移をトリガーするエンドポイントとレスポンスを提示

#### Group 4: バッチ処理・非同期処理設計（条件付）

`{components}` のバッチ/非同期コンポーネント + `{nfr_table}` から以下を導出:

- **ジョブ定義**: ジョブ名、トリガー条件（スケジュール/イベント）、処理内容、タイムアウト
- **データフロー**: 入力ソース → 処理 → 出力先
- **べき等性保証**: 重複実行時の安全性設計
- **リトライ/バックオフ**: ジョブごとの具体的なリトライ回数、バックオフ戦略

#### QG-1: 導出完全性ゲート（Phase 1 完了前）

全グループ議論後:

| # | チェック | 基準 |
|---|---------|------|
| 1 | エンティティカバレッジ | `{data_schema}` の全エンティティにテーブル定義がある |
| 2 | Service メソッドカバレッジ | `{components}` の全 Service に少なくとも1メソッド定義がある |
| 3 | Handler カバレッジ | ユーザーアクションを処理する全 Handler に API 契約がある |
| 4 | SR トレーサビリティ | 全 SR が少なくとも1仕様（カラム、メソッド、エンドポイント）にトレースされる |
| 5 | DI インターフェース完全性 | `{di_design}` の全抽象化ポイントにインターフェース定義がある |
| 6 | エラー型完全性 | `{error_handling}` の全エラー種別が具体的なシナリオにマッピングされている |

#### QG-1b: グループ間整合性ゲート（Phase 1 完了前、QG-1 後）

| # | 観点 | チェック内容 |
|---|------|------------|
| 1 | DB↔Service 型整合 | Service メソッドの引数/戻り値型がDBエンティティの型と整合する |
| 2 | Service↔API 契約整合 | API 入出力スキーマが対応する Service メソッドのシグネチャと整合する |
| 3 | エラー型一貫性 | Service が throw するエラー型が API のエラーレスポンス定義に全て含まれる |
| 4 | DI 境界整合 | DI インターフェースのメソッドシグネチャが仕様化された Service/Repository メソッドと一致する |

問題がある場合は個別提示し対応を確認:

```
### グループ間整合性の問題: {問題名}
- **関連する仕様**: {Group X 項目名} + {Group Y 項目名}
- **問題**: {不整合の具体的な内容}
- **対応案**: {修正提案}

対応方針を選んでください。
```

#### Phase 1 完了サマリ

```
### Phase 1 サマリ

- **テーブル定義**: {N}テーブル、カラム合計{M}
- **Service メソッド**: {N}メソッド（{M} Service）
- **API 契約**: Server Action {N}個、Route Handler {M}個
- **バッチ処理**: {N}ジョブ（or 該当なし）
- **状態遷移**: {N}エンティティ（or 該当なし）
- **SR カバレッジ**: {M}/{N}
- **グループ間整合性**: OK

修正があればお知らせください。問題なければ「ok」と回答してください。
```

承認後、全設計を `{work_dir}/design-decisions.md` に Write。

---

### Phase 2: 詳細設計書生成

**目的**: Phase 1 の確定情報を統合し `detailed-design.md` を生成する

#### Step 1: 文書生成（サブエージェント）

`Task`（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

```
`{skill_dir}/templates/generate-document.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{req_path}`: {req_path}
- `{arch_path}`: {arch_path}
- `{std_path}`: {std_path}
- `{dp_path}`: {dp_path}
- `{decisions_path}`: {work_dir}/design-decisions.md
- `{template_path}`: {skill_dir}/references/output-template.md
- `{output_save_path}`: {output_path}
```

#### Step 2: QG-2 トレーサビリティゲート

1. `{req_path}` から SR/NFR/IR の ID 一覧を取得
2. `{output_path}` のトレーサビリティセクションと突合
   - **SR カバレッジ**: 全 SR が仕様マッピングを持つか
   - **NFR 反映**: パフォーマンス/セキュリティ NFR がインデックス設計、認証要件等に反映されているか
   - **IR カバレッジ**: 全 IR が API 仕様にマッピングされているか

未対応がある場合はユーザーに提示し対応を確認。修正を Edit で反映した後、Step 3 へ。

#### Step 3: ユーザー確認

生成された `{output_path}` を Read し提示。修正指示があれば Edit で反映。

---

### Phase 3: 整合性チェック

**目的**: 内部整合性および上流文書との整合性を検証する

#### Step 0: 準備

`{check_loop}` = 0

#### Step 1: 整合性チェック実行

`Task`（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

```
`{skill_dir}/templates/check-consistency.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{design_path}`: {output_path}
- `{arch_path}`: {arch_path}
- `{std_path}`: {std_path}
- `{req_path}`: {req_path}
- `{findings_save_path}`: {work_dir}/consistency-check.md
```

サブエージェントの返答: `verdict` + `issues` + `summary`

#### Step 2: 結果に応じた処理

- **pass**: Phase 4 へ
- **needs_revision** かつ `{check_loop}` < 2: Step 3 へ
- **needs_revision** かつ `{check_loop}` >= 2: 手動修正を案内してスキル終了

#### Step 3: 修正

`Task`（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

```
`{skill_dir}/templates/fix-document.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{design_path}`: {output_path}
- `{findings_path}`: {work_dir}/consistency-check.md
```

修正サマリをテキスト出力する。`{check_loop}` += 1。Step 1 に戻る（再チェック）。

---

### Phase 4: 出力・完了

#### Step 1: ステータス更新

`{output_path}` のステータスを `Draft` → `Confirmed` に Edit で変更する。

#### Step 2: クリーンアップ

`{work_dir}` 内の一時ファイルを削除する（`rm -rf {work_dir}`）。

#### Step 3: 完了出力

```
## detailed_design 完了
- 入力: {4ファイルパス}
- 出力: {output_path}
- 整合性チェック: {check_loop + 1}ラウンド, verdict: pass

次のステップ:
1. `/task_decompose` でタスク分解に進んでください
```
