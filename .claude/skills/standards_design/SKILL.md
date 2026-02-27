---
allowed-tools: Glob, Grep, Read, Write, Edit, Task
description: アーキテクチャ設計書からユーザーとの対話を通じて開発規約を設計し、規約文書を生成するスキル
disable-model-invocation: true
---

アーキテクチャ設計書（`docs/project-definition/architecture.md`）と要件定義書（`docs/project-definition/requirements.md`）を入力として、P2 決定項目カタログの 5 固定グループを依存順に議論し、開発規約を確定する。技術選定が必要な判断ポイント（Linter/Formatter）では `/adr_create` コマンドの実行をユーザーに提示し、別セッションでの実行を促す。最終的に `docs/project-definition/standards.md` を生成する。整合性チェックを経て品質を担保する。

## 使い方

```
/standards_design
```

引数なし。`docs/project-definition/architecture.md` と `docs/project-definition/requirements.md` を入力として読み込む。

## 出力先

- `docs/project-definition/standards.md`（固定パス）
- `docs/adr/`（技術選定ADR群、副産物）

## パス変数

- `{skill_dir}`: このファイルが存在するディレクトリの絶対パス
- `{arch_path}`: `docs/project-definition/architecture.md` の絶対パス
- `{req_path}`: `docs/project-definition/requirements.md` の絶対パス
- `{output_path}`: `docs/project-definition/standards.md` の絶対パス
- `{adr_dir}`: `docs/adr/` の絶対パス
- `{work_dir}`: `.skill_output/standards_design/` の絶対パス

## コンテキスト管理方針

| 方針 | 適用箇所 |
|------|---------|
| 遅延読み込み | architecture.md は Phase 0 で構造サマリのみ抽出。p2-decision-catalog.md は Phase 1 のグループ議論開始時に読込 |
| 親コンテキスト最小化 | Phase 2/3 のコンテンツ生成・整合性チェックはサブエージェントに委譲。親には要約のみ返す |
| ファイル経由のデータ受渡し | Phase 1→2 は design-decisions.md 経由。Phase 3 のチェック結果はファイル保存 |
| リセットポイント | Phase 1→2 の境界（全規約を design-decisions.md に統合し、Phase 2 はファイルのみ参照） |

## 品質ゲート

| # | ゲート名 | 配置 | チェック内容 |
|---|---------|------|------------|
| QG-1 | 入力品質 | Phase 0 Step 1 | architecture.md の存在・非 Draft、requirements.md の存在 |
| QG-2 | ADR整合性 | Phase 1（各ADR読込後） | 新ADRが既存決定・他ADR・制約と矛盾しないか |
| QG-3 | 規約完全性 | Phase 1 完了前 | 全P2項目に規約確定 or N/A。P1引き継ぎ事項が反映されているか |
| QG-3b | 規約整合性 | Phase 1 完了前（QG-3後） | P1整合・規約間整合・実施可能性 |
| QG-4 | P1トレーサビリティ | Phase 2 Step 2 | standards.md が P1 引き継ぎ事項を反映し、技術スタック参照が正確か |
| QG-5 | 整合性チェック | Phase 3 | 項目間整合性 + architecture.md / requirements.md との整合性 |

## ワークフロー

Phase 0（初期化）→ 1（対話的規約設計）→ 2（規約文書生成）→ 3（整合性チェック）→ 4（出力・完了）

---

### Phase 0: 初期化

**目的**: 入力の検証、コンテキスト抽出、議論スコープの確認

#### Step 1: 入力ファイルの読み込みと検証

1. パス変数の設定（`{arch_path}`, `{req_path}`, `{output_path}`, `{adr_dir}`, `{work_dir}`, `{skill_dir}`）
2. `{arch_path}` = `docs/project-definition/architecture.md` を Read
   - 不在 → 「`architecture.md` が見つかりません。先に `/arch_design` を実行してください」エラー終了
   - ステータスが `Draft` → 「`architecture.md` がまだ Draft です。`/arch_design` で確定してから実行してください」エラー終了
3. `{req_path}` = `docs/project-definition/requirements.md` を Read
   - 不在 → 「`requirements.md` が見つかりません。先に `/requirement_define` を実行してください」エラー終了
   - ステータスが `Draft` → 警告を提示し続行するか確認

#### Step 2: 構造サマリの抽出

architecture.md から以下を抽出し親コンテキストに保持（全文は保持しない）:

- `{tech_stack}`: 技術スタックテーブル
- `{components}`: コンポーネント一覧（名前、責務、技術）
- `{cross_cutting}`: 横断的関心事（エラーハンドリング方針、ログ・監視、P2 への引き継ぎ事項）
- `{deploy_strategy}`: デプロイ戦略
- `{auth_strategy}`: 認証方式・セッション管理

requirements.md から以下を抽出し親コンテキストに保持（全文は保持しない）:

- `{nfr_list}`: 非機能要件テーブル
- `{constraints}`: 制約一覧

#### Step 3: 既存 ADR の確認

`{adr_dir}` を Glob し、既存 ADR の「決定」セクションのみ抽出して `{existing_adrs}` に保持。

#### Step 4: Phase 0 完了サマリと議論スコープの確認

```
### Phase 0 完了
- 入力: {arch_path}, {req_path}
- 技術スタック: {tech_stack サマリ}
- コンポーネント: {N}個
- 認証方式: {auth_strategy サマリ}
- 既存ADR: {N}件

### 議論スコープ

| # | グループ | 項目数 | 含める |
|---|---------|--------|--------|
| 1 | コーディングツール・スタイル規約 | 7 | ✓ |
| 2 | コードパターン規約 | 4 | ✓ |
| 3 | プロジェクト構成 | 6 | ✓ |
| 4 | セキュリティ・データ管理規約 | 10 | ✓ |
| 5 | フロントエンド UX・AI 統合規約 | 9 | {要件に基づく判断} |

修正があればお知らせください。問題なければ「ok」と回答してください。
```

`Bash` で `mkdir -p {work_dir}` を実行。承認後、スコープ計画を `{work_dir}/scope-plan.md` に保存。

**ユーザーチェックポイントの根拠**: スコープ決定は全後続フェーズの方向を規定する。特に Group 5 の AI 統合部分の含否は出力文書の構成に影響する。

---

### Phase 1: 対話的規約設計

**目的**: P2 カタログの各グループを依存順に議論し、全項目の規約を確定する

#### グループ議論のフロー

含まれるグループを順に以下のパターンで議論する:

##### 1. グループ提示

`{skill_dir}/references/p2-decision-catalog.md` から当該グループの項目テーブルを参照し、提示する。既存 ADR で解決済みの項目があればマークする。

##### 2. 規約の一括提案

グループ内の全項目について、P1 決定（`{tech_stack}`, `{cross_cutting}`, `{auth_strategy}` 等）と選定技術のベストプラクティスに基づき、規約を一括で提案する。各項目について:

- **直接決定**（大多数）: P1 決定から導出される規約を提案。根拠と、採用した技術のデフォルトとの関係（デフォルト準拠/カスタマイズ）を示す
- **ADR 提案**（Group 1 の Linter/Formatter のみ）: 複数の有力な候補があり、トレードオフ分析が必要な場合
- **N/A**: P1 の決定により該当しない場合。スキップ理由を明示

##### 3. ADR の提案（Group 1 のみ）

Linter/Formatter の ADR が必要な場合:

```
### 技術選定: {選定ポイント名}

この判断は選択肢のトレードオフ分析が必要です。
以下のコマンドを **別セッション** で実行してください:

`/adr_create {選定ポイント名}。スコープ: {対象項目リスト}。制約: {確定済み決定から導出した制約}`

完了したら「完了」と回答してください。
```

ADR グルーピングの判断基準:
- Linter + Formatter が連動する場合（Biome 等）は 1 ADR にまとめる
- 独立に判断できる場合は別 ADR にする

##### 4. ADR 読込と整合性検証（ADR がある場合のみ）

ユーザーが「完了」と回答したら:

1. `{adr_dir}` を Glob し、新 ADR を特定
2. 「決定」「受け入れたトレードオフ」セクションのみ Read
3. **QG-2**: 既存決定・他 ADR・`{constraints}` との矛盾検証
   - 矛盾検出時: ユーザーに提示し解決方法を相談
4. 決定を `{tool_decisions}` に追加
5. **後続影響チェック**: ADR の決定が同グループ・後続グループの項目に影響するか確認
   - 例: Biome 採用 → インポート順序ルール、フォーマット設定が Biome の機能で決定される

##### 5. グループ規約サマリと確認

グループ内の全項目を議論後、グループ規約サマリを提示:

```
### {グループ名} サマリ

| # | 項目 | 規約内容 | ADR | 根拠 |
|---|------|---------|-----|------|
| 1 | {項目名} | {確定した規約の要約} | {ADR-NNNN or —} | {根拠の要約} |
| ... | | | | |

修正があればお知らせください。問題なければ「ok」と回答してください。
```

**ユーザーチェックポイントの根拠**: 各グループの規約は後続グループの前提になる（特に Group 1 → 2, 3）。方向転換コストが高い。

#### QG-3: 規約完全性ゲート（Phase 1 完了前）

全グループ議論後:

1. P2 カタログの全項目に対して、規約が確定 or N/A 判定されているか
2. `{cross_cutting}` の P2 引き継ぎ事項が規約に反映されているか

```
### 規約完全性チェック

| チェック | 結果 | 詳細 |
|---------|------|------|
| P2 カタログ網羅 | {M}/{N} | 全項目に規約が確定しているか |
| P1 引き継ぎ反映 | {M}/{N} | P1 横断的関心事の P2 引き継ぎ事項が反映されているか |
```

未カバー項目がある場合は個別に提示:

```
### 未カバー: {項目名}
- **問題**: この項目に対する規約が未確定です
- **提案**: {P1 決定に基づく規約案}

対応しますか？
```

#### QG-3b: 規約整合性ゲート（Phase 1 完了前、QG-3 後）

QG-3 通過後、確定した全規約の組み合わせに対して以下の 3 観点を検証する:

| # | 観点 | チェック内容 | 検出例 |
|---|------|------------|--------|
| 1 | P1 との整合 | 確定した規約が P1 決定（技術スタック、アーキテクチャ方針）と矛盾しないか | React 採用なのに Vue のコンポーネント設計パターン、SSR 前提なのに CSR 前提のスタイリング規約 |
| 2 | 規約間の整合 | 規約同士が矛盾しないか | 命名規則と Linter ルールの不一致、ディレクトリ構成とモジュール境界の矛盾 |
| 3 | 実施可能性 | 規約が選定したツール（Linter/Formatter）で自動強制可能か、または手動遵守のみか | 独自の命名規則に対応する Linter ルールが存在しない |

```
### 規約整合性検証

| # | 観点 | 結果 | 詳細 |
|---|------|------|------|
| 1 | P1 との整合 | {OK / 問題あり {N}件} | {問題の概要} |
| 2 | 規約間の整合 | {OK / 問題あり {N}件} | {問題の概要} |
| 3 | 実施可能性 | {OK / 注意 {N}件} | {手動遵守のみの項目一覧} |
```

問題がある場合は個別に提示し対応を確認する:

```
### 規約整合性の問題: {問題名}
- **関連する規約**: {規約 A} + {規約 B}（+ {P1 決定}）
- **問題**: {矛盾・不整合の具体的な内容}
- **対応案**: {規約の変更 / リスク受容 / 自動化断念}

対応方針を選んでください。
```

**QG-5（整合性チェック）との役割分担**:
- QG-3b: 確定した規約の組み合わせに対する検証（Phase 1 の決定に対して実施。文書化前）
- QG-5: 規約文書に対する整合性チェック（standards.md に対して実施。文書化後）

#### Phase 1 完了サマリ

全 QG-3/3b 通過後:

```
### Phase 1 サマリ

- **Linter/Formatter**: {確定内容}（ADR {N}件）
- **コーディング規約**: {N}項目確定
- **プロジェクト構成**: {ディレクトリパターン} / {コンポーネント設計パターン}
- **セキュリティ規約**: {N}項目
- **データ管理規約**: {N}項目
- **FE UX 規約**: {N}項目
- **規約完全性**: {M}/{N} 項目確定、N/A {N} 項目
- **自動強制可能**: {N}項目 / 手動遵守: {N}項目

修正があればお知らせください。問題なければ「ok」と回答してください。
```

- 承認: Phase 1 確定情報の保存へ
- 修正指示: 修正を反映して再提示

**ユーザーチェックポイントの根拠**: Phase 1→2 はリセットポイント。全規約の方向性の最終確認が必要。

#### Phase 1 確定情報の保存

全決定を `{work_dir}/design-decisions.md` に Write:
- Linter/Formatter 選定結果（ADR 参照含む）
- グループ別規約一覧（各項目の確定規約 + 根拠 + 自動強制/手動遵守の区分）
- N/A 項目一覧と理由
- P1 引き継ぎ事項の反映状況

---

### Phase 2: 規約文書生成

**目的**: Phase 1 の確定情報を統合し `standards.md` を生成する

#### Step 1: 文書生成（サブエージェント）

`Task`（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

```
`{skill_dir}/templates/generate-document.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{arch_path}`: {arch_path}
- `{req_path}`: {req_path}
- `{decisions_path}`: {work_dir}/design-decisions.md
- `{template_path}`: {skill_dir}/references/output-template.md
- `{adr_dir}`: {adr_dir}
- `{output_save_path}`: {output_path}
```

#### Step 2: QG-4 P1 トレーサビリティゲート

1. `{arch_path}` の横断的関心事から P2 引き継ぎ事項を取得する
2. `{output_path}` の各規約セクションと突合する:
   - **P1 引き継ぎカバレッジ**: 全引き継ぎ事項が規約に反映されているか
   - **技術スタック整合**: 規約が参照する技術が `{tech_stack}` と一致しているか

```
### トレーサビリティ検証結果
- P1 引き継ぎ: {M}/{N}件 — 未反映: {項目リスト or なし}
- 技術スタック参照: {OK / 不一致 {N}件}
```

未対応がある場合はユーザーに提示し、規約追加 or 意図的除外を確認する。修正を Edit で反映した後、Step 3 へ。

#### Step 3: ユーザー確認

生成された `{output_path}` を Read し提示。修正指示があれば Edit で反映。

---

### Phase 3: 整合性チェック

**目的**: 規約間および上流文書との整合性を検証する

#### Step 0: 準備

`{check_loop}` = 0

#### Step 1: 整合性チェック実行

`Task`（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

```
`{skill_dir}/templates/check-consistency.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{design_path}`: {output_path}
- `{arch_path}`: {arch_path}
- `{req_path}`: {req_path}
- `{adr_dir}`: {adr_dir}
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
## standards_design 完了
- 入力: {arch_path}, {req_path}
- 出力: {output_path}
- ADR: {adr_dir} ({N}件)
- 整合性チェック: {check_loop + 1}ラウンド, verdict: pass

次のステップ:
1. `/process_design` で開発プロセス設計に進んでください
```
