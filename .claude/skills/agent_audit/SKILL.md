---
allowed-tools: Glob, Grep, Read, Write, Edit, Bash, Task, AskUserQuestion
description: エージェント定義の内容を静的に分析し、種別に応じた多次元の品質問題を特定・改善するスキル
---

エージェント定義ファイルのコンテンツ（評価基準、スコープ、指示の品質）を静的に分析し、構造最適化（agent_bench）では解決できない内容レベルの問題を特定・改善します。

エージェントの内容を解析してグループ（evaluator / producer / hybrid / unclassified）に分類し、グループに応じた分析次元セットで深い分析を行います。

入力はエージェント定義ファイル1つのみ。外部データへの依存なく、常に同じ分析を実行します。

## 使い方

```
/agent_audit <file_path>    # エージェント定義ファイルを指定して監査
```

- `file_path`: エージェント定義ファイルのパス（必須）

## コンテキスト節約の原則

1. **大量コンテンツの分析はサブエージェントに委譲する**
2. **サブエージェントからの返答は最小限にする**（詳細はファイルに保存させる）
3. **親コンテキストには要約・メタデータのみ保持する**

## グループと分析次元

エージェントの主たる機能に基づき4グループに分類し、グループごとの次元セットで分析する。

### グループ定義

| グループ | 定義 | 該当するエージェントタイプの例 |
|---------|------|--------------------------|
| **hybrid** | 評価と生成の両方を主要機能として持ち、入力の分析・問題検出と成果物の作成・修正の両方を行う | レビュー+修正、分析+レポート生成、監査+改善適用 |
| **evaluator** | 入力（設計書、コード、文書等）を評価基準に基づいて分析し、問題点や改善点を検出・報告することが主な機能 | 設計書レビュー、コードレビュー、品質監査、静的分析 |
| **producer** | 指示に従って成果物（文書、コード、計画、レポート等）を作成・変換・修正することが主な機能 | 文書作成、コード実装、プランニング、テスト生成、調査・検討、データ変換 |
| **unclassified** | 上記のいずれにも明確に分類できない | — |

### 次元マッピング

| グループ | 共通次元 | グループ固有次元 | 計 |
|---------|---------|----------------|---|
| hybrid | IC（指示明確性） | CE（基準有効性）, SA（スコープ整合性）, WC（ワークフロー完全性）, OF（出力形式実現性） | 5 |
| evaluator | IC（指示明確性） | CE（基準有効性）, SA（スコープ整合性）, DC（検出カバレッジ） | 4 |
| producer | IC（指示明確性） | WC（ワークフロー完全性）, OF（出力形式実現性）, SA（スコープ整合性・軽量版） | 4 |
| unclassified | IC（指示明確性） | SA（スコープ整合性・軽量版）, WC（ワークフロー完全性） | 3 |

## ワークフロー

Phase 0（初期化・グループ分類）→ Phase 1（並列分析）→ Phase 2（ユーザー承認 + 改善適用）→ Phase 3（完了サマリ）

---

### Phase 0: 初期化・グループ分類

1. 引数から `agent_path` を取得する（未指定の場合は `AskUserQuestion` で確認）
2. Read で `agent_path` のファイルを読み込み、`{agent_content}` として保持する。読み込み失敗時はエラー出力して終了
3. ファイル内容の簡易チェック: ファイル先頭に YAML frontmatter（`---` で囲まれたブロック内に `description:` を含む）が存在するか確認する。存在しない場合、「⚠ このファイルにはエージェント定義の frontmatter がありません。エージェント定義ではない可能性があります。」とテキスト出力する（処理は継続する）

#### グループ分類

4. `{agent_content}` を分析し、`{agent_group}` を以下の基準で判定する:

   エージェント定義の **主たる機能** に注目して分類する。分類基準の詳細は `.claude/skills/agent_audit/group-classification.md` を参照。

   判定ルール（概要）:
   1. evaluator 特徴が3つ以上 **かつ** producer 特徴が3つ以上 → **hybrid**
   2. evaluator 特徴が3つ以上 → **evaluator**
   3. producer 特徴が3つ以上 → **producer**
   4. 上記いずれにも該当しない → **unclassified**

   この判定はメインコンテキストで直接行う（サブエージェント不要）。

#### 共通初期化

5. `{agent_name}` を以下のルールで導出する:
   - `agent_path` が `.claude/` 配下の場合: `.claude/` からの相対パスの拡張子を除いた部分
     - 例: `.claude/agents/security-design-reviewer.md` → `agents/security-design-reviewer`
   - それ以外の場合: プロジェクトルートからの相対パスの拡張子を除いた部分
     - 例: `my-agents/custom.md` → `my-agents/custom`
6. 出力ディレクトリを作成する: `mkdir -p .agent_audit/{agent_name}/`

#### 分析次元セットの決定

7. `{agent_group}` に基づき分析次元セットを決定する:

   | agent_group | dimensions（エージェントファイルパス） |
   |-------------|--------------------------------------|
   | `hybrid` | `shared/instruction-clarity`, `evaluator/criteria-effectiveness`, `evaluator/scope-alignment`, `producer/workflow-completeness`, `producer/output-format` |
   | `evaluator` | `shared/instruction-clarity`, `evaluator/criteria-effectiveness`, `evaluator/scope-alignment`, `evaluator/detection-coverage` |
   | `producer` | `shared/instruction-clarity`, `producer/workflow-completeness`, `producer/output-format`, `unclassified/scope-alignment` |
   | `unclassified` | `shared/instruction-clarity`, `unclassified/scope-alignment`, `producer/workflow-completeness` |

   `{dim_count}` = dimensions のリスト長

テキスト出力:
```
## Phase 0: 初期化
- エージェント: {agent_name} ({agent_path})
- グループ: {agent_group}
- 分析次元: {dim_count}件（{各次元名のカンマ区切り}）
- 出力先: .agent_audit/{agent_name}/
```

---

### Phase 1: 並列分析

テキスト出力: `## Phase 1: コンテンツ分析 ({agent_group}) — {dim_count}次元を並列分析中...`

`{dim_count}` 個の `Task` を同一メッセージ内で並列起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）。

各次元について、以下の Task prompt を使用する:

> `.claude/skills/agent_audit/agents/{dim_path}.md` を Read し、その指示に従って分析を実行してください。
> 分析対象: `{agent_path}`, agent_name: `{agent_name}`
> findings の保存先: `{findings_save_path}`（= `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` の絶対パス）
> 分析完了後、以下のフォーマットで返答してください: `dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`

`{dim_path}` は dimensions テーブルの各エントリ（例: `evaluator/criteria-effectiveness`）。
`{ID_PREFIX}` は各次元の Finding ID Prefix（CE, IC, SA, DC, WC, OF）。

全サブエージェントの完了を待ち、各返答サマリを収集する。

**エラーハンドリング**: 各サブエージェントの成否を以下で判定する:
- 対応する findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）が存在し、空でない → 成功。件数はファイル内の `## Summary` セクションから抽出する（抽出失敗時は findings ファイル内の `### {ID_PREFIX}-` ブロック数から推定する）
- findings ファイルが存在しない、または空 → 失敗。Task ツールの返答から例外情報（エラーメッセージの要約）を抽出し、該当次元は「分析失敗（{エラー概要}）」として扱う

全て失敗した場合: 「Phase 1: 全次元の分析に失敗しました。」とエラー出力して終了する。

テキスト出力:
```
Phase 1 完了: {成功数}/{dim_count}
- {次元名}: critical {N}, improvement {M}, info {K}（または「分析失敗（{エラー概要}）」）
（各次元を1行ずつ表示）
```

全次元の critical + improvement の合計が 0 の場合、「対象となる指摘はありませんでした。」とテキスト出力し、Phase 2 をスキップして Phase 3 へ直行する。

---

### Phase 2: ユーザー承認 + 改善適用

テキスト出力: `## Phase 2: ユーザー承認`

#### Step 1: Findings の収集

Phase 1 で成功した全次元の findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）を Read する。
各ファイルから severity が critical または improvement の finding（`###` ブロック単位）を抽出し、critical → improvement の順にソートする。
`{total}` = 対象 finding の合計件数。

#### Step 2: 一覧提示 + 承認方針の選択

対象 findings の一覧をテキスト出力する:
```
### 対象 findings: 計{total}件（critical {N}, improvement {M}）
| # | ID | severity | title | 次元 |
|---|-----|----------|-------|------|
| 1 | {ID} | {severity} | {title} | {次元名} |
...
```

続けて `AskUserQuestion` で承認方針を確認:
- **「全て承認」**: 全 findings を承認として Step 3 へ進む
- **「1件ずつ確認」**: Step 2a の per-item 承認ループに入る
- **「キャンセル」**: 改善適用なしで Phase 3 へ直行する

#### Step 2a: Per-item 承認（「1件ずつ確認」選択時のみ）

各 finding に対して以下をテキスト出力する:
```
### [{N}/{total}] {ID}: {title} ({severity})
- 次元: {次元名}
- 内容: {description}
- 根拠: {evidence}
- 推奨: {recommendation}

---
```

続けて `AskUserQuestion` で方針確認（選択肢は以下の4つ。ユーザーが "Other" で修正内容をテキスト入力した場合は「修正して承認」として扱い、改善計画に含める）:
- **「承認」**: この指摘を改善計画に含める。次の指摘へ進む
- **「スキップ」**: この指摘を改善計画から除外する。次の指摘へ進む
- **「残りすべて承認」**: この指摘を含め、未確認の全指摘を承認としてループを終了する
- **「キャンセル」**: 全指摘の確認を中止し、Phase 3 へ直行する

#### Step 3: 承認結果の保存

承認された指摘（ユーザー修正内容を含む）を `.agent_audit/{agent_name}/audit-approved.md` に Write で保存する。

フォーマット:
```
# 承認済み監査 Findings

承認: {承認数}/{total}件（スキップ: {スキップ数}件）

## 重大な問題

### {ID}: {title} [{次元名}]
- 内容: {description}
- 根拠: {evidence}
- 推奨: {recommendation}
- **ユーザー判定**: 承認 / 修正して承認
- **修正内容**: {修正して承認の場合のみ記載}

## 改善提案

（同形式で承認された改善提案を記載）
```

承認数が 0 の場合: 「全ての指摘がスキップされました。改善の適用はありません。」とテキスト出力し、Phase 3 へ直行する。

#### Step 4: 改善適用（サブエージェントに委譲）

テキスト出力: `改善を適用しています...`

**バックアップ作成**: 改善適用前に Bash で `cp {agent_path} {agent_path}.backup-$(date +%Y%m%d-%H%M%S)` を実行し、`{backup_path}` を記録する。

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_audit/templates/apply-improvements.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{agent_path}`: {実際の agent_path の絶対パス}
- `{approved_findings_path}`: {実際の .agent_audit/{agent_name}/audit-approved.md の絶対パス}

サブエージェント完了後、返答内容（変更サマリ）をテキスト出力する。

#### 検証ステップ

改善適用完了後、以下の検証を実行する:

1. Read で `{agent_path}` を再読み込み
2. YAML frontmatter の存在確認（ファイル先頭が `---` で始まり、`description:` を含む）
3. 検証成功時: 「✓ 検証完了: エージェント定義の構造は正常です」とテキスト出力
4. 検証失敗時: 「✗ 検証失敗: エージェント定義が破損している可能性があります。以下のコマンドでロールバックできます: `cp {backup_path} {agent_path}`」とテキスト出力し、Phase 3 でも警告を表示

---

### Phase 3: 完了サマリ

Phase 1 で収集した各 severity の件数と、Phase 2 の承認結果を使用する。

Phase 2 がスキップされた場合（critical + improvement = 0）:
```
## agent_audit 完了
- エージェント: {agent_name}
- ファイル: {agent_path}
- グループ: {agent_group}
- 分析次元: {dim_count}件（{各次元名}）
- 検出: critical 0件, improvement 0件, info {K}件
- 改善対象なし（全基準が有効と判定されました）
```

Phase 2 が実行された場合:
```
## agent_audit 完了
- エージェント: {agent_name}
- ファイル: {agent_path}
- グループ: {agent_group}
- 分析次元: {dim_count}件（{各次元名}）
- 検出: critical {N}件, improvement {M}件, info {K}件
- 承認: {approved}/{total}件（スキップ: {skip}件）
- 変更詳細:
  - 適用成功: {N}件（{finding ID リスト}）
  - 適用スキップ: {K}件（{finding ID: スキップ理由}）
- バックアップ: {backup_path}（変更を取り消す場合: `cp {backup_path} {agent_path}`）
```

スキップされた critical findings がある場合、追加で表示:
```
- ⚠ スキップされた critical findings: {ID リスト}
  手動確認を推奨します
```

**次のステップ**（承認結果に応じて条件分岐）:
- critical findings を承認・適用した場合: `次のステップ: 再度 /agent_audit {agent_path} で修正結果を確認してください`
- improvement のみ適用した場合: `次のステップ: /agent_bench {agent_path} で構造最適化を検討できます`
- 承認が 0 件の場合: 次のステップは表示しない
