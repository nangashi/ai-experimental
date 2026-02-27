# skill_design 全体設計書

## 概要

Claude Code スキルを AI 主導で設計・実装・評価するワークフロー。4つの独立スキルで構成され、ファイルベースの接続仕様により各スキルを任意の組み合わせで実行できる。

## 4スキル構成

| スキル | コマンド | 目的 | 主要入力 | 主要出力 |
|--------|---------|------|---------|---------|
| skill_require | `/skill_require {skill_name}` | 要求整理＋評価基準策定 | ユーザー対話 | requirements.md, evaluation.md |
| skill_design | `/skill_design {skill_name}` | ワークフロー議論＋設計書作成 | requirements.md, evaluation.md | design-spec.md |
| skill_implement | `/skill_implement {skill_name}` | 設計書に基づく実装 | design-spec.md | スキルディレクトリ一式 |
| skill_evaluate | `/skill_evaluate {skill_name}` | 実行記録の評価＋改善 | evaluation.md, スキルディレクトリ, 実行記録 | test-results.md, improvements.md |

## データフロー

```
skill_require          skill_design          skill_implement        skill_evaluate
┌────────────┐      ┌────────────┐       ┌──────────────┐      ┌──────────────────┐
│ 対話的      │      │ 案出し      │       │ SKILL.md生成  │      │ 実行記録収集      │
│ 要件定義    │      │ 人間選定    │       │ テンプレート   │      │ 評価・スコアリング │
│ 評価基準策定│      │ 攻撃者議論  │       │ リファレンス   │      │ 失敗分析          │
│ テストケース │      │ 設計書生成  │       │ デプロイ       │      │ 改善実装          │
│            │      │            │       │ 構造検証      │      │                  │
└─────┬──────┘      └─────┬──────┘       └──────┬───────┘      └────────┬─────────┘
      │                   │                      │                      │
      ▼                   ▼                      ▼                      ▼
 requirements.md    design-spec.md         .claude/skills/        test-results.md
 evaluation.md                             {skill_name}/          improvements.md
```

### ファイル間の依存関係

```
requirements.md ──→ skill_design（入力）
evaluation.md  ──→ skill_design（参照）──→ skill_evaluate（入力）
design-spec.md ──→ skill_implement（入力）
スキルディレクトリ ──→ skill_evaluate（テスト対象）
```

## 推奨パス

### フルパス（推奨）

全4スキルを順に実行する標準ワークフロー。

```
skill_require → skill_design → skill_implement → skill_evaluate
```

### 評価のみ

既存スキルに evaluation.md を後付けして評価・改善する。

```
skill_require（評価基準のみ） → skill_evaluate
```

前提: 対象スキルが既にデプロイ済みで、実行記録が蓄積されていること。skill_require で evaluation.md を作成し、skill_evaluate で実行記録の評価・改善を実行する。

### 設計のみ

設計書の作成までで止め、実装は手動で行う。

```
skill_require → skill_design
```

design-spec.md を手動実装のブループリントとして使用する。

---

## 接続仕様

### 1. evaluation.md スキーマ

skill_require が出力し、skill_design（参照）と skill_evaluate（入力）が消費する。

```markdown
# {skill_name} 評価基準

## メタデータ
- skill_name: {skill_name}
- created_at: {ISO 8601}

## 評価基準

| # | 基準名 | 説明 | 最低品質ライン | 重み |
|---|--------|------|--------------|------|
| E-{N} | {基準名} | {1行の説明} | {N}/5 | {1-3} |

### E-{N}: {基準名}

**説明**: {詳細な説明}

**ルーブリック**:

| レベル | 説明 | 具体例 |
|--------|------|--------|
| 1 | {最低レベル} | {具体例} |
| 2 | {不十分} | {具体例} |
| 3 | {許容} | {具体例} |
| 4 | {良好} | {具体例} |
| 5 | {卓越} | {具体例} |

（E-{N} ごとに繰り返し）

## テストケース

| # | 種別 | 入力概要 | 検証する基準 | 期待レベル |
|---|------|---------|------------|----------|
| TC-{N} | {正常系/異常系/境界値} | {1行の概要} | E-{N}, ... | E-{N}≥{M}, ... |

### TC-{N}: {概要}

**種別**: {正常系/異常系/境界値}

**シナリオ条件**:
{このテストケースに該当する実行記録の条件。どのような状況・入力で使用された記録が対象か}

**期待される品質**:
- E-{N}: ≥{M} — {この基準で期待する具体的な品質}
（対象基準ごとに繰り返し）

（TC-{N} ごとに繰り返し）
```

### 2. design-spec.md スキーマ

skill_design が出力し、skill_implement が消費する。

```markdown
# {skill_name} 詳細設計書

## メタデータ
- skill_name: {skill_name}
- created_at: {ISO 8601}
- based_on: requirements.md, evaluation.md

## スキル概要
- **目的**: {スキルの目的}
- **コマンド**: `/{skill_name} {args}`
- **利用者**: {誰が使うか}
- **利用文脈**: {どんな場面で}

## ワークフロー

### Phase {N}: {フェーズ名}

**目的**: {フェーズの目的}

**入力**:
- {入力ファイルまたはユーザー入力}

**処理**:
1. {処理ステップ}
2. {処理ステップ}

**出力**:
- {出力ファイルまたはユーザーへの提示}

**人間関与**: {必須/任意/なし} — {関与内容}

（Phase ごとに繰り返し）

## ファイル構成

```
.claude/skills/{skill_name}/
  SKILL.md
  references/
    {file}.md              # {説明}
  templates/
    {file}.md              # {説明}
```

## サブエージェント定義

| ID | Phase | モデル | 入力ファイル | 出力ファイル | 並列化 |
|----|-------|--------|------------|------------|--------|
| SA-{N} | Phase {M} | {sonnet/haiku} | {入力} | {出力} | {可/不可/条件付き} |

## 出力構造設計

### 実行ディレクトリ

スキル実行ごとに `{output_dir}/runs/{run_id}/` を作成し、全成果物をここに出力する。

### ディレクトリレイアウト

```
{output_dir}/runs/{run_id}/
  work/                    # サブエージェント中間成果物
    {file}.md              # {説明}
  {final_output}.md        # 最終成果物
```

### エビデンスマッピング

| 評価基準 | エビデンスとなる成果物 | パス |
|---------|-------------------|------|
| E-{N} | {どの中間/最終成果物が根拠か} | runs/{run_id}/{path} |

## エラーハンドリング

| エラー種別 | 検出方法 | 対応 |
|-----------|---------|------|
| {エラー} | {検出方法} | {対応方法} |

## 人間関与ポイント

| タイミング | 関与内容 | 必須/任意 |
|-----------|---------|----------|
| Phase {N} | {関与内容} | {必須/任意} |
```

### 3. requirements.md スキーマ

skill_require が出力し、skill_design が消費する。design.md Phase 0A の出力形式を踏襲する。

```markdown
# {skill_name} 要件定義

## メタデータ
- skill_name: {skill_name}
- created_at: {ISO 8601}

## 要件
- **目的**: {スキルの目的}
- **利用者**: {誰が使うか}
- **利用文脈**: {どんな場面で}
- **成功イメージ**: {理想的な出力の具体例}
- **失敗イメージ**: {避けたい失敗の具体例}
- **優先順位**: {トレードオフ判断}
```

---

## 作業ディレクトリ構造

```
.skill_output/.skill_design/{skill_name}/
  requirements.md             # skill_require 出力
  evaluation.md               # skill_require 出力
  design-spec.md              # skill_design 出力
  test-results.md             # skill_evaluate 出力
  improvements.md             # skill_evaluate 出力
  work/                       # サブエージェントの中間ファイル
    candidates-raw.md         # skill_design: 案出し結果
    attacker-{1,2}.md         # skill_design: 攻撃者出力
    defender-{1,2}.md         # skill_design: 擁護者出力
    judge.md                  # skill_design: 判定者出力
    record-tc{N}.md           # skill_evaluate: 実行記録（TC対応付け済み）
    eval-tc{N}.md             # skill_evaluate: 評価結果
    skill-md-draft.md         # skill_implement: SKILL.md ドラフト
    template-{name}.md        # skill_implement: テンプレートドラフト
    reference-{name}.md       # skill_implement: リファレンスドラフト
```

### パス変数規約

| 変数 | 値 | 説明 |
|------|---|------|
| `{skill_name}` | ユーザー指定 | 設計対象のスキル名 |
| `{command_name}` | skill_require / skill_design / skill_implement / skill_evaluate | 実行中のスキルコマンド名 |
| `{work_dir}` | `.skill_output/.skill_design/{skill_name}` | 作業ディレクトリ |
| `{skill_dir}` | `.claude/skills/{command_name}` | 実行中のスキルディレクトリ |
| `{target_skill_dir}` | `.claude/skills/{skill_name}` | 生成先のスキルディレクトリ |

---

## 共通規約

### コンテキスト節約の原則

1. **参照ファイルは使用する Phase でのみ読み込む**（先読みしない）
2. **大量コンテンツの生成はサブエージェントに委譲する**
3. **サブエージェントからの返答は最小限にする**（詳細はファイルに保存させる）
4. **親コンテキストには要約・メタデータのみ保持する**
5. **サブエージェント間のデータ受け渡しはファイル経由で行う**（親を中継しない）

### サブエージェント起動パターン

テンプレートファイルを Read で読み込ませ、パス変数を渡す統一パターンを使用する:

```
Task（{model}）:
「`{skill_dir}/templates/{template}.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
- {追加変数}: {値}」
```

サブエージェントは処理結果をファイルに保存し、件数サマリーのみを返す。

### エラーハンドリング共通方針

- **サブエージェント失敗**: エラー内容をユーザーに提示し、AskUserQuestion で「リトライ」/「中止」を選択させる。リトライは1回のみ。2回目の失敗でスキル終了
- **前提ファイル不在**: 必要な前提スキルの実行を案内して終了
- **評価基準の不足**: 評価中に evaluation.md でカバーされないケースが判明した場合、追加を提案する

### テンプレート/リファレンス分離規約

| 種別 | 配置 | 用途 |
|------|------|------|
| references/ | 定義・基準（読み取り専用） | 出力スキーマ、ルーブリック |
| templates/ | サブエージェント実行指示 | 生成・評価・分析の指示 |

---

## design.md からの要素マッピング

### 設計判断

| design.md | 移設先 | 扱い |
|-----------|--------|------|
| D1: セッション分離単位 | overview.md | 3コマンド→4スキルに再設計。根拠は踏襲 |
| D2: フル版/軽量版 | 削除 | クイックモード廃止。このスキルを使わない軽量設計ではスキル自体を使用しない |
| D3: 評価基準の二段階策定 | skill_require.md Phase 2 | そのまま保持 |
| D4: 攻撃者議論のサブエージェント構成 | skill_design.md Phase 3 | そのまま保持 |
| D5: テスト実行の設計 | skill_evaluate.md Phase 1 | シミュレーション方式→実行記録ベースの評価に変更 |
| D6: 比較評価方式 | 削除 | 改善ループ廃止に伴い比較評価を削除 |
| D7: テンプレート/リファレンス分離 | overview.md 共通規約 | そのまま保持 |

### フェーズ

| design.md | 移設先 |
|-----------|--------|
| Phase 0A: 対話的要件定義 | skill_require.md Phase 1 |
| Phase 0B: 評価基準・テストケース | skill_require.md Phase 2-3 |
| Phase 1: 案出し | skill_design.md Phase 1 |
| Phase 2: 人間選定 | skill_design.md Phase 2 |
| Phase 3: 攻撃者議論 | skill_design.md Phase 3 |
| Phase 4: 実装 | skill_implement.md Phase 1-4 |
| Phase 5: テスト実行・評価 | skill_evaluate.md Phase 1-2（実行記録ベースに変更） |
| Phase 6: 失敗分析 | skill_evaluate.md Phase 3 |
| 改善ラウンド | skill_evaluate.md Phase 4（単発改善、ループ廃止） |

### 新規追加要素

| 要素 | 所在 | 目的 |
|------|------|------|
| 出力構造設計 | skill_design.md Phase 4 | 実行記録の自動収集と評価基準へのマッピング |
| design-spec.md 生成 | skill_design.md Phase 4 | 実装ブレを防ぐ詳細設計書 |
| 構造検証 | skill_implement.md Phase 5 | デプロイ後のファイル整合性チェック |

---

## 人間関与ポイント（全体）

| スキル | タイミング | 関与内容 | 必須/任意 |
|--------|-----------|---------|----------|
| skill_require | Phase 1 | 対話的要件定義への参加 | 必須 |
| skill_require | Phase 4 | 評価基準・テストケースの承認 | 必須 |
| skill_design | Phase 2 | 案の選定 | 必須 |
| skill_design | Phase 3 | 攻撃者議論の結果確認 | 必須 |
| skill_design | Phase 4 | 設計書の承認 | 必須 |
| skill_implement | Phase 4 | デプロイ前の確認 | 必須 |
| skill_evaluate | Phase 1 | 評価対象の実行記録選択・対応付け確認 | 必須 |
| skill_evaluate | Phase 2 | スコアリングの校正 | 必須 |
| skill_evaluate | Phase 3 | 失敗分析結果の確認・改善実施判断 | 必須 |
| skill_evaluate | Phase 4 | 改善方向性の選択 | 必須 |
