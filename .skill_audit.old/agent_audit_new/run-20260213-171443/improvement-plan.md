# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | パス変数リストへの{run_dir}追加、Phase 2 Step 4 返答パース処理明示、Phase 0 Step 4 グループ分類理由判定追加、スキル目的の出力ファイル明記、グループ分類のサブエージェント委譲統一、Phase 1 の analyze-dimensions.md 参照削除、Phase 2 Step 4 モデル指定変更（sonnet→haiku） | C-1, C-2, C-3, I-1, I-2, I-3, I-4, I-5 |
| 2 | group-classification.md | 修正 | サブエージェント返答フォーマットの追加 | I-3 |
| 3 | templates/consolidate-findings.md | 新規作成 | Phase 2 Step 1 findings 抽出アルゴリズムの外部化 | I-6 |

## 削除推奨ファイル
| ファイル | 理由 | 対応フィードバック |
|---------|------|------------------|
| templates/analyze-dimensions.md | 内容が SKILL.md Phase 1 のサブエージェント prompt と完全に重複しており冗長 | I-5 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）

**対応フィードバック**:
- C-1: 参照整合性: 未定義パス変数の使用
- C-2: 出力フォーマット決定性: Phase 2 Step 4 サブエージェント返答のパース方法未定義
- C-3: 条件分岐の完全性: グループ分類失敗時の具体的理由の判定処理が未定義
- I-1: 目的の明確性: 具体的成果物の記述不足
- I-2: Phase 0 グループ分類の判定ロジック不整合
- I-3: Phase 0 グループ分類のサブエージェント返答フォーマットが未定義
- I-4: templates/apply-improvements.md model指定
- I-5: templates/analyze-dimensions.md 冗長性
- I-6: Phase 2 Step 1 findings抽出のテンプレート外部化

**変更内容**:

#### 1-1: パス変数リストへの {run_dir} 追加（C-1）
- **行30-40 パス変数セクション**: 以下の行を追加
  ```markdown
  - `{run_dir}`: 実行ごとのタイムスタンプ付きディレクトリパス（.agent_audit/{agent_name}/run-{timestamp}）
  ```

#### 1-2: スキル目的への出力ファイル明記（I-1）
- **行6-13 スキル目的セクション**: 出力セクションを以下に置換
  ```markdown
  - **出力**:
    - `.agent_audit/{agent_name}/run-{timestamp}/audit-{ID_PREFIX}.md`（各次元の findings）
    - `.agent_audit/{agent_name}/run-{timestamp}/audit-approved.md`（承認済み findings）
    - `.agent_audit/{agent_name}/audit-approved.md`（最新版へのシンボリックリンク）
    - `{agent_path}.backup-{timestamp}`（改善適用前バックアップ）
  ```

#### 1-3: Phase 0 Step 4 グループ分類のサブエージェント委譲統一（I-2, I-3）
- **行84-92 グループ分類セクション**: 現在の手順（行85-92）を以下に置換
  ```markdown
  4. Read で `{skill_path}/group-classification.md` を読み込み、Task ツールでサブエージェント（`subagent_type: "general-purpose"`, `model: "haiku"`）を起動する:
     > `{skill_path}/group-classification.md` を Read し、その判定基準に従ってグループ分類を実行してください。
     >
     > パス変数:
     > - `{agent_path}`: {実際の agent_path の絶対パス}
     >
     > 分析完了後、以下のフォーマットで返答してください（1行固定）:
     > ```
     > group: {hybrid|evaluator|producer|unclassified}
     > ```

     サブエージェント返答から `group:` 行を抽出し、`{agent_group}` に格納する。
  ```

#### 1-4: Phase 0 Step 4 グループ分類失敗時の理由判定追加（C-3）
- **行94-95 判定失敗時セクション**: 行95の後に以下を挿入
  ```markdown
  具体的な理由の判定:
  1. サブエージェント返答が `group:` 行を含まない → "返答フォーマット不正"
  2. サブエージェント返答の group 値が hybrid/evaluator/producer/unclassified 以外 → "不正なグループ値: {値}"
  3. サブエージェント起動失敗（Task ツールエラー） → "サブエージェント起動失敗"
  ```

#### 1-5: Phase 0 Step 6 への {run_dir} 変数保持の明示（C-1）
- **行106-108**: 行108の後に以下を挿入
  ```markdown
  - パス変数 `{run_dir}` に環境変数 `$RUN_DIR` の値を保持する（Phase 1 で使用）
  ```

#### 1-6: Phase 1 の analyze-dimensions.md 参照削除（I-5）
- **行145-166 Phase 1 サブエージェント prompt**: analyze-dimensions.md への参照を削除し、prompt を直接記述する形式に統一（現状のまま維持、テンプレートファイル参照を削除）

#### 1-7: Phase 2 Step 1 findings 抽出のテンプレート外部化（I-6）
- **行195-214 Phase 2 Step 1**: 現在のインライン手順（行203-213）を以下に置換
  ```markdown
  Task ツールでサブエージェント（`subagent_type: "general-purpose"`, `model: "haiku"`）を起動する:
  > `{skill_path}/templates/consolidate-findings.md` を Read し、その指示に従って findings を抽出してください。
  >
  > パス変数:
  > - `{run_dir}`: {実際の run ディレクトリの絶対パス}
  > - `{findings_list_path}`: {実際の .agent_audit/{agent_name}/run-{timestamp}/findings-list.json の絶対パス}
  >
  > 抽出完了後、以下のフォーマットで返答してください（1行固定）:
  > ```
  > total: {N}
  > ```

  サブエージェント返答から `total:` 行を抽出し、`{total}` に格納する。

  Read で `{findings_list_path}` を読み込み、JSON形式の findings リストをパースする。
  ```

#### 1-8: Phase 2 Step 4 返答パース処理の明示（C-2）
- **行293-294**: 行293の後に以下を挿入
  ```markdown

  サブエージェント返答から `modified:` 行と `skipped:` 行を抽出する:
  1. 正規表現 `^modified: (\d+)件` で modified 件数を抽出
  2. 正規表現 `^skipped: (\d+)件` で skipped 件数を抽出
  3. 抽出失敗時は警告を表示「⚠ サブエージェント返答から変更サマリを抽出できませんでした。」し、検証ステップで modified: 0件として扱う
  ```

#### 1-9: Phase 2 Step 4 モデル指定変更（I-4）
- **行285**: `model: "sonnet"` → `model: "haiku"` に変更

---

### 2. group-classification.md（修正）

**対応フィードバック**: I-3: Phase 0 グループ分類のサブエージェント返答フォーマットが未定義

**変更内容**:

#### 2-1: 返答フォーマットの追加
- **ファイル末尾**: 以下のセクションを追加
  ```markdown

  ## 返答フォーマット

  判定完了後、以下のフォーマットで返答してください（1行固定）:
  ```
  group: {hybrid|evaluator|producer|unclassified}
  ```

  - `{hybrid|evaluator|producer|unclassified}`: 判定結果のグループ名（いずれか1つ）
  ```

---

### 3. templates/consolidate-findings.md（新規作成）

**対応フィードバック**: I-6: Phase 2 Step 1 findings抽出のテンプレート外部化

**変更内容**: 新規ファイルとして以下の内容を作成

```markdown
# Findings 抽出・統合テンプレート

`{run_dir}` ディレクトリ内の全 findings ファイル（audit-*.md）から critical および improvement の findings を抽出し、統合リストを生成してください。

## パス変数
- `{run_dir}`: 実行ごとのタイムスタンプ付きディレクトリパス（.agent_audit/{agent_name}/run-{timestamp}）
- `{findings_list_path}`: 抽出結果の保存先パス（.agent_audit/{agent_name}/run-{timestamp}/findings-list.json）

## 手順

1. Glob で `{run_dir}/audit-*.md` のパターンにマッチする全ファイルを検出する
2. 各ファイルを Read し、以下の方法で finding を抽出する:
   1. `### {ID}: {title} [{severity}]` 形式の行をブロック開始マーカーとして検出
   2. 次の `###` 行または `##` 行までをブロックとして抽出
   3. ブロック内の必須フィールド（`- 内容:`, `- 根拠:`, `- 推奨:`）を抽出
   4. 必須フィールドが1つでも欠落している場合、その finding はスキップし、警告を表示: 「⚠ {ファイル名} の {ID} は必須フィールドが欠落しているためスキップしました。」
   5. severity フィールドのバリデーション:
      - フィールド欠落時: 該当 finding をスキップし、警告表示「⚠ {ファイル名} の {ID} は severity フィールドが欠落しているためスキップしました。」
      - 不正値（critical/improvement/info 以外）: 該当 finding をスキップし、警告表示「⚠ {ファイル名} の {ID} は認識できない severity 値 "{値}" のためスキップしました。」
   6. severity が `critical` または `improvement` の finding のみを対象とする
3. 抽出した findings を severity 順（critical → improvement）にソートする
4. JSON形式で `{findings_list_path}` に Write で保存する:
   ```json
   {
     "findings": [
       {
         "id": "CE-1",
         "title": "...",
         "severity": "critical",
         "dimension": "基準有効性",
         "description": "...",
         "evidence": "...",
         "recommendation": "..."
       },
       ...
     ]
   }
   ```

## 返答フォーマット

以下のフォーマットで返答してください（1行固定）:
```
total: {N}
```

- `{N}`: 抽出された finding の合計件数（critical + improvement のみ）
```

---

## 新規作成ファイル
| ファイル | 目的 | 対応フィードバック |
|---------|------|------------------|
| templates/consolidate-findings.md | Phase 2 Step 1 の findings 抽出アルゴリズムを外部化し、SKILL.md のコンテキスト負荷を削減 | I-6 |

## 削除推奨ファイル
| ファイル | 理由 | 対応フィードバック |
|---------|------|------------------|
| templates/analyze-dimensions.md | 内容が SKILL.md Phase 1 のサブエージェント prompt と完全に重複しており、テンプレート参照のオーバーヘッドが無駄 | I-5 |

## 実装順序

1. **templates/consolidate-findings.md（新規作成）** - Phase 2 Step 1 で参照されるため先に作成
2. **group-classification.md（修正）** - Phase 0 で参照され、SKILL.md の変更前に完了させる必要がある
3. **SKILL.md（修正）** - 全変更の中心であり、consolidate-findings.md と group-classification.md への参照を含むため最後に実施
4. **templates/analyze-dimensions.md（削除推奨）** - SKILL.md の変更完了後、手動で削除を検討

依存関係の理由:
- consolidate-findings.md（新規作成）→ SKILL.md（修正）: SKILL.md Phase 2 Step 1 で consolidate-findings.md を参照するため、先に作成する必要がある
- group-classification.md（修正）→ SKILL.md（修正）: SKILL.md Phase 0 Step 4 で group-classification.md の返答フォーマットを前提とするため、先に修正する必要がある

## 注意事項

- **SKILL.md の変更 1-7 と 1-8 は相互依存**: Phase 2 Step 1 のテンプレート外部化（1-7）と Phase 2 Step 4 の返答パース（1-8）は独立した変更だが、両方とも Phase 2 の手順に影響するため、同時に適用して整合性を確認すること
- **{run_dir} パス変数の追加**: C-1 対応として、パス変数リストへの追加（1-1）と Phase 0 Step 6 への保持明示（1-5）の両方が必要
- **グループ分類のサブエージェント化**: I-2, I-3 対応として、SKILL.md（1-3）と group-classification.md（2-1）の両方を変更する必要がある
- **analyze-dimensions.md 削除前の確認**: 削除前に、SKILL.md の Phase 1 が analyze-dimensions.md への参照を含まないことを確認すること（変更 1-6 が適用済みであること）
- **テンプレート外部化による SKILL.md のサイズ削減**: 変更 1-7 により Phase 2 Step 1 のインライン手順（約20行）がテンプレート参照（約15行）に置換され、約5行削減される
