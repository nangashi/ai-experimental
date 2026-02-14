# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 1 サブエージェント返答検証・推定処理の明示化 | C-1 |
| 2 | SKILL.md | 修正 | Phase 0 Step 3 frontmatter 欠落時の処理継続条件の明示化 | C-2 |
| 3 | SKILL.md | 修正 | Phase 2 Fast mode フラグ取得・判定条件の追加 | C-4 |
| 4 | SKILL.md | 修正 | Phase 1 冒頭に既存 findings ファイル検索・警告出力を追加 | C-5 |
| 5 | SKILL.md | 修正 | Phase 0 Step 4 の判定ルール概要を削除し group-classification.md への参照に置換（行数削減） | C-6, I-4 |
| 6 | SKILL.md | 修正 | Phase 0 Step 4 に group-classification.md 不在時のエラー処理を追加 | I-5 |
| 7 | SKILL.md | 修正 | Phase 1 部分失敗時のエラー概要抽出処理を明示化 | I-6 |
| 8 | SKILL.md | 修正 | Phase 1 エラーハンドリングに部分続行判定基準を追加 | I-8 |
| 9 | SKILL.md | 修正 | Phase 2 検証ステップに findings の部分適用整合性チェックを追加 | I-3 |
| 10 | SKILL.md | 修正 | Phase 2 Step 4 検証ステップに必須フィールド・セクション存在確認を追加 | I-7 |
| 11 | templates/apply-improvements.md | 修正 | テンプレート冒頭に「## パス変数」セクションを追加 | C-3 |
| 12 | agents/shared/detection-process-common.md | 新規作成 | Detection-First, Reporting-Second プロセスを外部化 | I-2 |
| 13 | agents/evaluator/criteria-effectiveness.md | 修正 | プロセス説明を shared/detection-process-common.md への参照に置換 | I-2 |
| 14 | agents/evaluator/detection-coverage.md | 修正 | プロセス説明を shared/detection-process-common.md への参照に置換 | I-2 |
| 15 | agents/evaluator/scope-alignment.md | 修正 | プロセス説明を shared/detection-process-common.md への参照に置換 | I-2 |
| 16 | agents/producer/workflow-completeness.md | 修正 | プロセス説明を shared/detection-process-common.md への参照に置換 | I-2 |
| 17 | agents/producer/output-format.md | 修正 | プロセス説明を shared/detection-process-common.md への参照に置換 | I-2 |
| 18 | agents/shared/instruction-clarity.md | 修正 | プロセス説明を shared/detection-process-common.md への参照に置換 | I-2 |
| 19 | agents/unclassified/scope-alignment.md | 修正 | プロセス説明を shared/detection-process-common.md への参照に置換 | I-2 |

## 各ファイルの変更詳細

### 1. templates/apply-improvements.md（修正）
**対応フィードバック**: C-3: 参照整合性: テンプレート内プレースホルダの定義欠落

**変更内容**:
- 行1-2（ファイル冒頭）: 「以下の手順で承認済み監査 findings...」の前に「## パス変数」セクションを新規追加
- 新規セクション内容:
```markdown
## パス変数
- `{approved_findings_path}`: 承認済み findings ファイルのパス
- `{agent_path}`: エージェント定義ファイルのパス
- `{backup_path}`: バックアップファイルのパス
```

### 2. agents/shared/detection-process-common.md（新規作成）
**対応フィードバック**: I-2: テンプレート間の説明重複

**変更内容**:
- 新規ファイルとして作成
- 内容: 全エージェント定義ファイルで共通している「Analysis Process - Detection-First, Reporting-Second」セクション（約20行）を外部化
- 構造:
```markdown
---
name: detection-process-common
description: Detection-First, Reporting-Second プロセスの共通説明
---

**Analysis Process - Detection-First, Reporting-Second**:
Conduct your review in two distinct phases: first detect all problems comprehensively (including adversarially), then organize and report them.

（各ファイルに共通する Phase 1/Phase 2 の概要説明）
```

### 3. SKILL.md（修正）
**対応フィードバック**: C-1, C-2, C-4, C-5, C-6, I-3, I-4, I-5, I-6, I-7, I-8

**変更内容**:

#### C-4: Phase 0 に Fast mode フラグ取得を追加
- 行64（Phase 0 Step 1 の後）: 新規ステップを挿入
```markdown
1a. Fast mode フラグの確認: 引数に `--fast` が含まれる場合は `{fast_mode} = true` を設定する（デフォルト: false）
```

#### C-2: Phase 0 Step 3 の処理継続条件の明示化
- 行66: 「処理は継続する」→「処理は継続する（frontmatter 欠落は警告のみ。グループ分類以降のステップは通常通り実行する）」

#### C-6, I-4: Phase 0 Step 4 の判定ルール概要を group-classification.md への参照に置換
- 行71-80（判定ルール概要）: 削除
- 行70（判定基準の直後）: 以下を挿入
```markdown
   判定基準の詳細は `group-classification.md` を参照する。
```

#### I-5: group-classification.md 不在時のエラー処理を追加
- 行70（上記参照挿入の直後）: 以下を追加
```markdown
   `group-classification.md` が存在しない場合: 「✗ エラー: group-classification.md が見つかりません。スキルの初期化に失敗しました。」とテキスト出力して終了する。
```

#### C-5: Phase 1 冒頭に既存 findings ファイル検索・警告出力を追加
- 行117（Phase 1 冒頭、テキスト出力の前）: 以下を挿入
```markdown
Glob で既存 findings ファイル（`.agent_audit/{agent_name}/audit-*.md`）を検索する。既存ファイルが1つ以上存在する場合、「⚠ 既存の findings ファイル {N}件を上書きします」とテキスト出力する。
```

#### C-1: サブエージェント返答フォーマット検証の明示化
- 行141-142: 以下に置換
```markdown
- 対応する findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）が存在し、空でない（0バイトでなく、かつ `## Summary` セクションを含む） → 成功。件数はサブエージェント返答から抽出する（正規表現 `critical: (\d+)` 等で抽出し、抽出失敗時は findings ファイル内の `### {ID_PREFIX}-` ブロック数をカウントして推定する）
```

#### I-6: Phase 1 部分失敗時のエラー概要抽出処理を明示化
- 行143-144: 以下に置換
```markdown
- findings ファイルが存在しない、または空（0バイトまたは `## Summary` セクションが存在しない） → 失敗。Task ツールの返答から例外情報（エラーメッセージの要約。返答から "Error:" または "Exception:" を含む最初の文を抽出する）を抽出し、該当次元は「分析失敗（{エラー概要}）」として扱う。エラー概要が抽出できない場合は「不明なエラー」とする
```

#### I-8: 部分続行判定基準の明示化
- 行145（全失敗時のエラー出力）の後: 以下を挿入
```markdown

部分失敗の場合: 以下の判定基準に従って処理を継続するか決定する:
- **継続条件**: 成功した次元数 ≧ 1、かつ（IC 次元が成功 または 成功数 ≧ 2）
- **中止条件**: 成功数が 0、または（IC 次元が失敗 かつ 成功数 = 1）
中止条件に該当する場合: 「Phase 1: 必須次元の分析に失敗しました。処理を中止します。失敗理由:\n- {次元名}: {エラー概要}\n（各失敗次元を列挙）」とエラー出力して終了する。
継続条件に該当する場合: Phase 2 へ進む。
```

#### C-4: Phase 2 Fast mode 分岐の実装指示
- 行163: 以下に置換
```markdown
`{fast_mode}` が true の場合、Step 2 の承認確認をスキップし、全 findings を自動承認として Step 3 へ進む（テキスト出力: "Fast mode: 全 findings を自動承認します"）。
```

#### I-3: Phase 2 検証ステップに部分適用整合性チェックを追加
- 行169（Step 1 の後）: 以下を挿入
```markdown
**部分適用時の整合性チェック**: Phase 1 で部分失敗が発生していた場合（失敗次元が存在する場合）、収集された findings に失敗次元の ID プレフィックスを含む finding が存在しないことを確認する。存在する場合は「⚠ 内部エラー: 失敗次元 {次元名} の findings が含まれています。処理を中止します。」とエラー出力して終了する。
```

#### I-7: Phase 2 Step 4 検証ステップの構造検証強化
- 行228: 以下に置換
```markdown
2. YAML frontmatter の存在確認（ファイル先頭が `---` で始まり、`description:` を含む）およびファイル内に `## ` で始まる見出し行が1つ以上存在することを確認する
```

## 新規作成ファイル
| ファイル | 目的 | 対応フィードバック |
|---------|------|------------------|
| agents/shared/detection-process-common.md | Detection-First, Reporting-Second プロセス説明を外部化し、全エージェント定義で参照する | I-2 |

## 削除推奨ファイル
（なし）

## 実装順序
1. **templates/apply-improvements.md**: パス変数セクションの追加（他の変更に依存しない）
2. **agents/shared/detection-process-common.md**: 新規テンプレート作成（agents/ 配下の変更が参照する）
3. **agents/ 配下の全ファイル（6ファイル）**: プロセス説明をテンプレート参照に置換（detection-process-common.md の存在が前提）
4. **SKILL.md**: 全変更を適用（group-classification.md への参照を追加するが、このファイルは既存）

依存関係の検出方法:
- 改善 I-2（テンプレート新規作成）→ agents/ 配下のファイル変更（テンプレート参照追加）→ I-2 が先
- 改善 C-3（templates/apply-improvements.md）は独立、改善 C-6/I-4（SKILL.md）は既存ファイル（group-classification.md）を参照するため依存なし

## 注意事項
- SKILL.md の変更により行数が 262行 → 約240行に削減される見込み（C-6 対応）
- agents/ 配下の各ファイルは、プロセス説明の削除により約15-20行削減される見込み（I-2 対応）
- Fast mode フラグ（C-4）は Phase 0 で取得し Phase 2 で参照するため、親コンテキストで `{fast_mode}` 変数を保持する必要がある
- 部分適用の整合性チェック（I-3）は Phase 1 の部分失敗情報（失敗次元リスト）を Phase 2 で参照するため、親コンテキストで保持する必要がある
- group-classification.md の不在時のエラー処理（I-5）を追加したことで、SKILL.md は group-classification.md への明示的な依存関係を持つ
