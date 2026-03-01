---
allowed-tools: Glob, Grep, Read, Write, Edit, Task
description: アーキテクチャ設計書と開発規約書からユーザーとの対話を通じて開発プロセスを設計し、プロセス設計書を生成するスキル
disable-model-invocation: true
---

アーキテクチャ設計書（`docs/project-definition/architecture.md`）、開発規約書（`docs/project-definition/standards.md`）、要件定義書（`docs/project-definition/requirements.md`）を入力として、P3 決定項目カタログの 5 固定グループを依存順に議論し、開発プロセスを確定する。技術選定が必要な判断ポイントでは `/adr_create` コマンドの実行をユーザーに提示し、別セッションでの実行を促す。最終的に `docs/project-definition/development-process.md` を生成する。整合性チェックを経て品質を担保する。

## 使い方

```
/process_design
```

引数なし。`docs/project-definition/architecture.md`、`docs/project-definition/standards.md`、`docs/project-definition/requirements.md` を入力として読み込む。

## 出力先

- `docs/project-definition/development-process.md`（固定パス）
- `docs/adr/`（技術選定ADR群、副産物）

## パス変数

- `{skill_dir}`: このファイルが存在するディレクトリの絶対パス
- `{arch_path}`: `docs/project-definition/architecture.md` の絶対パス
- `{std_path}`: `docs/project-definition/standards.md` の絶対パス
- `{req_path}`: `docs/project-definition/requirements.md` の絶対パス
- `{output_path}`: `docs/project-definition/development-process.md` の絶対パス
- `{adr_dir}`: `docs/adr/` の絶対パス
- `{work_dir}`: `.skill_output/process_design/` の絶対パス

## コンテキスト管理方針

| 方針 | 適用箇所 |
|------|---------|
| 遅延読み込み | architecture.md・standards.md は Phase 0 で構造サマリのみ抽出。p3-decision-catalog.md は Phase 1 のグループ議論開始時に読込 |
| 親コンテキスト最小化 | Phase 2/3 のコンテンツ生成・整合性チェックはサブエージェントに委譲。親には要約のみ返す |
| ファイル経由のデータ受渡し | Phase 1→2 は design-decisions.md 経由。Phase 3 のチェック結果はファイル保存 |
| リセットポイント | Phase 1→2 の境界（全プロセスを design-decisions.md に統合し、Phase 2 はファイルのみ参照） |

## 品質ゲート

| # | ゲート名 | 配置 | チェック内容 |
|---|---------|------|------------|
| QG-1 | 入力品質 | Phase 0 Step 1 | architecture.md・standards.md の存在・非 Draft、requirements.md の存在 |
| QG-2 | ADR整合性 | Phase 1（各ADR読込後） | 新ADRが既存決定・他ADR・制約と矛盾しないか |
| QG-3 | プロセス完全性 | Phase 1 完了前 | 全P3項目にプロセス確定 or N/A。P1/P2引き継ぎ事項が反映されているか |
| QG-3b | プロセス整合性 | Phase 1 完了前（QG-3後） | P1整合・P2整合・プロセス間整合・プロジェクト文脈適合性 |
| QG-4 | P1/P2トレーサビリティ | Phase 2 Step 2 | P1/P2引き継ぎ反映 + 品質チェック配置の一貫性 |
| QG-5 | 整合性チェック | Phase 3 | プロセス間整合 + architecture.md / standards.md / requirements.md との整合性 |

## ワークフロー

Phase 0（初期化）→ 1（対話的プロセス設計）→ 2（文書生成）→ 3（整合性チェック）→ 4（出力・完了）

---

### Phase 0: 初期化

**目的**: 入力の検証、コンテキスト抽出、議論スコープの確認

#### Step 1: 入力ファイルの読み込みと検証

1. パス変数の設定（`{arch_path}`, `{std_path}`, `{req_path}`, `{output_path}`, `{adr_dir}`, `{work_dir}`, `{skill_dir}`）
2. `{arch_path}` = `docs/project-definition/architecture.md` を Read
   - 不在 → 「`architecture.md` が見つかりません。先に `/arch_design` を実行してください」エラー終了
   - ステータスが `Draft` → エラー終了
3. `{std_path}` = `docs/project-definition/standards.md` を Read
   - 不在 → 「`standards.md` が見つかりません。先に `/standards_design` を実行してください」エラー終了
   - ステータスが `Draft` → 「`standards.md` がまだ Draft です。`/standards_design` で確定してから実行してください」エラー終了
4. `{req_path}` = `docs/project-definition/requirements.md` を Read
   - 不在 → 「`requirements.md` が見つかりません。先に `/requirement_define` を実行してください」エラー終了

#### Step 2: 構造サマリの抽出

architecture.md から以下を抽出し親コンテキストに保持（全文は保持しない）:

- `{tech_stack}`: 技術スタックテーブル
- `{components}`: コンポーネント一覧（名前、責務、技術）
- `{deploy_strategy}`: デプロイ戦略
- `{hosting}`: ホスティングプラットフォーム
- `{cross_cutting}`: 横断的関心事（P3 への引き継ぎ事項）

standards.md から以下を抽出し親コンテキストに保持（全文は保持しない）:

- `{linter_formatter}`: Linter/Formatter 選定結果
- `{coding_conventions}`: コーディング規約サマリ（命名規則、エラーハンドリングパターン等）
- `{directory_structure}`: ディレクトリ構成（ツリー + 役割テーブル）
- `{quality_enforcement}`: 規約の自動強制サマリ
- `{p3_handoff}`: P3 への引き継ぎ事項

requirements.md から以下を抽出し親コンテキストに保持（全文は保持しない）:

- `{nfr_list}`: 非機能要件テーブル
- `{constraints}`: 制約一覧

#### Step 3: 既存 ADR の確認

`{adr_dir}` を Glob し、既存 ADR の「決定」セクションのみ抽出して `{existing_adrs}` に保持。

#### Step 4: Phase 0 完了サマリと議論スコープの確認

```
### Phase 0 完了
- 入力: {arch_path}, {std_path}, {req_path}
- 技術スタック: {tech_stack サマリ}
- ホスティング: {hosting}
- デプロイ戦略: {deploy_strategy サマリ}
- Linter/Formatter: {linter_formatter}
- 既存ADR: {N}件

### 議論スコープ

| # | グループ | 項目数 | 含める |
|---|---------|--------|--------|
| 1 | Git ワークフロー・開発プロセス | 5 | ✓ |
| 2 | テスト戦略 | 7 | ✓ |
| 3 | CI/CD・環境管理 | 6 | ✓ |
| 4 | インフラ・運用プロセス | 8 | ✓ |
| 5 | 開発環境・AI 統合 | 7 | {要件に基づく判断} |

修正があればお知らせください。問題なければ「ok」と回答してください。
```

`Bash` で `mkdir -p {work_dir}` を実行。承認後、スコープ計画を `{work_dir}/scope-plan.md` に保存。

**ユーザーチェックポイントの根拠**: スコープ決定は全後続フェーズの方向を規定する。特に Group 5 の AI 統合部分の含否。

---

### Phase 1: 対話的プロセス設計

**目的**: P3 カタログの各グループを依存順に議論し、全項目のプロセス設計を確定する

#### グループ議論のフロー

含まれるグループを順に以下のパターンで議論する:

##### 1. グループ提示

`{skill_dir}/references/p3-decision-catalog.md` から当該グループの項目テーブルを参照し、提示する。既存 ADR で解決済みの項目があればマークする。

##### 2. プロセスの提案

グループ内の全項目について、P1 決定（`{tech_stack}`, `{hosting}`, `{deploy_strategy}`）、P2 規約（`{linter_formatter}`, `{quality_enforcement}`）、およびプロジェクト文脈（個人開発、MVP）に基づき、プロセスを提案する。各項目について:

- **直接決定**: P1/P2 決定や制約から選択肢が 1 つに絞られる場合。根拠を示して決定
- **ADR 提案**: 複数の有力な候補がありトレードオフ分析が必要な場合
- **N/A**: P1 の決定により該当しない場合（例: PWA 不採用時の Service Worker 設定）。スキップ理由を明示

##### 3. ADR の提案とグルーピング

ADR が必要な項目について:

```
### 技術選定: {選定ポイント名}

この判断は選択肢のトレードオフ分析が必要です。
以下のコマンドを **別セッション** で実行してください:

`/adr_create {選定ポイント名}。スコープ: {対象項目リスト}。制約: {確定済み決定から導出した制約}`

完了したら「完了」と回答してください。
```

ADR グルーピングの判断基準:
- 同一 ADR にまとめるべき: 選択肢が相互に制約し合う項目
- 別 ADR にすべき: 独立に判断でき、組み合わせの影響が小さい項目

##### 4. ADR 読込と整合性検証（ADR がある場合）

ユーザーが「完了」と回答したら:

1. `{adr_dir}` を Glob し、新 ADR を特定
2. 「決定」「受け入れたトレードオフ」セクションのみ Read
3. **QG-2**: 既存決定・他 ADR・`{constraints}` との矛盾検証
   - 矛盾検出時: ユーザーに提示し解決方法を相談
4. 決定を追加
5. **後続影響チェック**: ADR の決定が同グループ・後続グループの項目に影響するか確認
   - 例: GitHub Actions 採用 → IaC の選択肢が変化
   - 例: Trunk-based 採用 → ブランチ戦略が簡素化、リリースプロセスが変化

##### 5. グループサマリと確認

グループ内の全項目を議論後:

```
### {グループ名} サマリ

| # | 項目 | 決定内容 | ADR | 根拠 |
|---|------|---------|-----|------|
| 1 | {項目名} | {確定した内容の要約} | {ADR-NNNN or —} | {根拠の要約} |
| ... | | | | |

修正があればお知らせください。問題なければ「ok」と回答してください。
```

**ユーザーチェックポイントの根拠**: Group 1→2→3 は強い依存チェーン。各グループの決定が後続の前提になる。

#### Group 3 固有: 品質チェック配置サマリの作成

Group 3（CI/CD）の議論完了時、P2 の `{quality_enforcement}` と Group 2（テスト戦略）の結果を統合して品質チェック配置サマリを作成する:

```
### 品質チェック配置サマリ

| チェック | 保存時 | commit 時 | push 時 | CI | CD | 備考 |
|---------|-------|----------|---------|-----|-----|------|
| {チェック名} | {○/—} | {○/—} | {○/—} | {○/—} | {○/—} | {備考} |

設計原則:
- commit 時: 高速なチェックのみ（変更ファイル対象の lint/format）
- push 時: 中量のチェック（型チェック等）
- CI: 全量チェック（テスト全量、ビルド検証、セキュリティスキャン）
- CD: デプロイ前ゲート（E2E テスト等）
- 重複排除: 同一チェックが複数タイミングに配置されていないことを確認

修正があればお知らせください。問題なければ「ok」と回答してください。
```

品質チェック配置サマリは Group 3 サマリとは別のユーザーチェックポイントとする。**根拠**: P2 規約（lint/format）と P3 プロセス（テスト/CI/CD）の統合地点であり、配置ミスは CI の信頼性に直結する。

#### QG-3: プロセス完全性ゲート（Phase 1 完了前）

全グループ議論後:

1. P3 カタログの全項目に対して、プロセスが確定 or N/A 判定されているか
2. `{cross_cutting}` と `{p3_handoff}` の引き継ぎ事項がプロセスに反映されているか。引き継ぎ事項に未解決の条件分岐（「確認後に選択」「利用不可の場合は〜」等）が含まれている場合、P3 で解決（調査・確定）した上で反映する

```
### プロセス完全性チェック

| チェック | 結果 | 詳細 |
|---------|------|------|
| P3 カタログ網羅 | {M}/{N} | 全項目にプロセスが確定しているか |
| P1 引き継ぎ反映 | {M}/{N} | architecture.md の P3 引き継ぎ事項が反映されているか |
| P2 引き継ぎ反映 | {M}/{N} | standards.md の P3 引き継ぎ事項が反映されているか |
| P1 引き継ぎ解決状態 | {M}/{N} | P1 引き継ぎ事項内の条件分岐が全て解決されているか |
| P2 引き継ぎ解決状態 | {M}/{N} | P2 引き継ぎ事項内の条件分岐が全て解決されているか |
```

未カバー項目がある場合は個別に提示し対応を確認。

#### QG-3b: プロセス整合性ゲート（Phase 1 完了前、QG-3 後）

QG-3 通過後、確定した全プロセスの組み合わせに対して以下の 4 観点を検証する:

| # | 観点 | チェック内容 | 検出例 |
|---|------|------------|--------|
| 1 | P1 との整合 | プロセスが P1 決定（ホスティング、デプロイ戦略）と矛盾しないか | サーバーレスなのにコンテナベースの CD、Edge 配信なのにマルチ環境デプロイ |
| 2 | P2 との整合 | プロセスが P2 規約（Linter/Formatter、品質ツール）と整合しているか | CI に P2 で選定していない Linter を使用、P2 の commit hook と CI のチェックが重複 |
| 3 | プロセス間の整合 | プロセス同士が矛盾しないか | Trunk-based なのに長寿命 feature ブランチを前提とした CI、テスト戦略と CI 実行戦略の不一致 |
| 4 | プロジェクト文脈の適合性 | プロセスが個人開発・MVP 文脈に対して過剰でないか | 個人開発で 3 段階の承認フロー、MVP でカナリアデプロイ |

```
### プロセス整合性検証

| # | 観点 | 結果 | 詳細 |
|---|------|------|------|
| 1 | P1 との整合 | {OK / 問題あり {N}件} | {問題の概要} |
| 2 | P2 との整合 | {OK / 問題あり {N}件} | {問題の概要} |
| 3 | プロセス間の整合 | {OK / 問題あり {N}件} | {問題の概要} |
| 4 | プロジェクト文脈 | {OK / 注意 {N}件} | {過剰な項目一覧} |
```

問題がある場合は個別に提示し対応を確認。

**QG-5（整合性チェック）との役割分担**:
- QG-3b: 確定したプロセスの組み合わせに対する検証（Phase 1 の決定に対して実施。文書化前）
- QG-5: プロセス文書に対する整合性チェック（development-process.md に対して実施。文書化後）

#### Phase 1 完了サマリ

全 QG-3/3b 通過後:

```
### Phase 1 サマリ

- **Git ワークフロー**: {確定内容}
- **テスト戦略**: {投資配分} / テスト FW: {確定内容}
- **CI/CD**: {プラットフォーム} / CI {N}ステージ + CD {N}ステージ
- **インフラ・運用**: マイグレーション({方式}), エラートラッキング({ツール})
- **DX**: {確定内容サマリ}
- **ADR**: {N}件
- **プロセス完全性**: {M}/{N} 項目確定、N/A {N} 項目

修正があればお知らせください。問題なければ「ok」と回答してください。
```

- 承認: Phase 1 確定情報の保存へ
- 修正指示: 修正を反映して再提示

**ユーザーチェックポイントの根拠**: Phase 1→2 はリセットポイント。全プロセスの方向性の最終確認。

#### Phase 1 確定情報の保存

全決定を `{work_dir}/design-decisions.md` に Write:
- グループ別プロセス一覧（各項目の確定内容 + ADR 参照 + 根拠）
- 品質チェック配置サマリ（P2 品質ツール + P3 テスト/CI を統合）
- N/A 項目一覧と理由
- P1/P2 引き継ぎ事項の反映状況

---

### Phase 2: プロセス文書生成

**目的**: Phase 1 の確定情報を統合し `development-process.md` を生成する

#### Step 1: 文書生成（サブエージェント）

`Task`（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

```
`{skill_dir}/templates/generate-document.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{arch_path}`: {arch_path}
- `{req_path}`: {req_path}
- `{std_path}`: {std_path}
- `{decisions_path}`: {work_dir}/design-decisions.md
- `{template_path}`: {skill_dir}/references/output-template.md
- `{adr_dir}`: {adr_dir}
- `{output_save_path}`: {output_path}
```

#### Step 2: QG-4 P1/P2 トレーサビリティゲート

1. `{arch_path}` の横断的関心事から P3 引き継ぎ事項を取得する
2. `{std_path}` の「P3 への引き継ぎ事項」を取得する
3. `{output_path}` の各セクションと突合する:
   - **P1 引き継ぎカバレッジ**: 全引き継ぎ事項がプロセスに反映されているか
   - **P2 引き継ぎカバレッジ**: 全引き継ぎ事項がプロセスに反映されているか
   - **品質チェック配置の一貫性**: P2 の自動強制サマリと P3 の品質チェック配置サマリに矛盾がないか

```
### トレーサビリティ検証結果
- P1 引き継ぎ: {M}/{N}件 — 未反映: {項目リスト or なし}
- P2 引き継ぎ: {M}/{N}件 — 未反映: {項目リスト or なし}
- 品質チェック配置: {OK / 不一致 {N}件}
```

未対応がある場合はユーザーに提示し、追加 or 意図的除外を確認。修正を Edit で反映した後、Step 3 へ。

#### Step 3: ユーザー確認

生成された `{output_path}` を Read し提示。修正指示があれば Edit で反映。

---

### Phase 3: 整合性チェック

**目的**: プロセス間および上流文書との整合性を検証する

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

修正サマリをテキスト出力する。`{check_loop}` += 1。Step 1 に戻る。

---

### Phase 4: 出力・完了

#### Step 1: クリーンアップ

`{work_dir}` 内の一時ファイルを削除する（`rm -rf {work_dir}`）。

#### Step 2: 完了出力

```
## process_design 完了
- 入力: {arch_path}, {std_path}, {req_path}
- 出力: {output_path}
- ADR: {adr_dir} ({N}件)
- 整合性チェック: {check_loop + 1}ラウンド, verdict: pass

次のステップ:
1. `/issue_create` でタスク分解に進んでください
```
