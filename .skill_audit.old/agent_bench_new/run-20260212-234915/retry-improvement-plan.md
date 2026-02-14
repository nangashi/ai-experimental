# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 0 perspective 解決ロジックを外部化、Phase 6 性能推移テーブル生成を外部化、Phase 6 デプロイ手順を外部化（合計削減目標: 40-50行） | C-7: SKILL.md が目標行数を超過 |
| 2 | templates/phase0-perspective-resolution.md | 新規作成 | perspective 検索・フォールバック・コピー処理を外部化（約20行） | C-7: SKILL.md が目標行数を超過 |
| 3 | templates/phase6-performance-table.md | 新規作成 | 性能推移テーブル生成とAskUserQuestion提示ロジックを外部化（約25行） | C-7: SKILL.md が目標行数を超過 |
| 4 | templates/phase6-deploy.md | 新規作成 | プロンプトデプロイ手順をテンプレート化（約15行） | C-7: SKILL.md が目標行数を超過 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**: C-7: SKILL.md が目標行数を超過

**変更内容**:

#### 変更箇所1: Phase 0 パースペクティブの解決（48-62行相当）
- **現在の記述**: 20行の詳細な検索ロジック（a/b/c分岐、パターンマッチ、コピー処理）
- **改善後の記述**:
```markdown
#### パースペクティブの解決

4. `Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_bench_new/templates/phase0-perspective-resolution.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{agent_name}`: Phase 0 で決定した値
- `{agent_path}`: エージェント定義ファイルの絶対パス
- `{perspective_source_path}`: `.agent_bench/{agent_name}/perspective-source.md` の絶対パス
- `{perspective_path}`: `.agent_bench/{agent_name}/perspective.md` の絶対パス

サブエージェント失敗時: パースペクティブ自動生成（後述）を実行する
サブエージェント成功時: 次の共通処理へ進む
```
- **削減**: 約12行削減（20→8行）

#### 変更箇所2: Phase 6 ステップ1 性能推移テーブル生成（262-278行相当）
- **現在の記述**: 17行のテーブル構築・AskUserQuestion・選択肢提示ロジック
- **改善後の記述**:
```markdown
#### ステップ1: プロンプト選択とデプロイ

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_bench_new/templates/phase6-performance-table.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{knowledge_path}`: `.agent_bench/{agent_name}/knowledge.md` の絶対パス
- `{phase5_summary}`: Phase 5 のサブエージェント返答（7行サマリ）
- `{round_number}`: 現在のラウンド番号

サブエージェント返答: 選択されたプロンプト名（ベースライン or バリアント名）
```
- **削減**: 約10行削減（17→7行）

#### 変更箇所3: Phase 6 ステップ1 デプロイ処理（281-289行相当）
- **現在の記述**: 9行のデプロイ手順（Task起動、メタデータ除去、上書き保存）
- **改善後の記述**:
```markdown
選択されたプロンプトに応じて:
- **ベースライン以外を選択した場合**: `Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "haiku"`）:

  `.claude/skills/agent_bench_new/templates/phase6-deploy.md` を Read で読み込み、その内容に従って処理を実行してください。
  パス変数:
  - `{selected_prompt_path}`: 選択されたプロンプトファイルの絶対パス
  - `{agent_path}`: エージェント定義ファイルの絶対パス

- **ベースラインを選択した場合**: 変更なし
```
- **削減**: 約4行削減（9→5行）

**総削減**: 約26行削減（372→346行）

### 2. templates/phase0-perspective-resolution.md（新規作成）
**対応フィードバック**: C-7: SKILL.md が目標行数を超過

**変更内容**:
- **目的**: perspective 検索・フォールバック・コピー処理をテンプレート化
- **構造**:
```markdown
# Perspective 解決テンプレート

以下の手順で perspective を検索・解決してください:

## パス変数
- `{agent_name}`: エージェント名
- `{agent_path}`: エージェント定義ファイルの絶対パス
- `{perspective_source_path}`: `.agent_bench/{agent_name}/perspective-source.md` の絶対パス
- `{perspective_path}`: `.agent_bench/{agent_name}/perspective.md` の絶対パス

## 手順

**Step 1: 既存 perspective-source.md の確認**
- Read で `{perspective_source_path}` を読み込む
- 読み込み成功 → Step 4 へ
- 読み込み失敗 → Step 2 へ

**Step 2: ファイル名パターンマッチ判定**
- `{agent_path}` のファイル名（拡張子なし）が `{key}-{target}-reviewer` パターンに一致するか判定する:
  - `*-design-reviewer` → `{key}` = `-design-reviewer` の前の部分, `{target}` = `design`
  - `*-code-reviewer` → `{key}` = `-code-reviewer` の前の部分, `{target}` = `code`
  - 一致しない場合 → 失敗として返答し終了

**Step 3: フォールバック検索とコピー**
- `.claude/skills/agent_bench_new/perspectives/{target}/{key}.md` を Read で読み込む
- 読み込み成功:
  - `{perspective_source_path}` に Write でコピーする
  - Step 4 へ
- 読み込み失敗 → 失敗として返答し終了

**Step 4: 作業コピー作成**
- Read で `{perspective_source_path}` を読み込む
- 「## 問題バンク」セクション以降を除外した内容を `{perspective_path}` に Write で保存する
- 以下の1行を返答する:
  ```
  perspective 解決完了: {既存 / フォールバック検索}
  ```
```
- **行数**: 約50行

### 3. templates/phase6-performance-table.md（新規作成）
**対応フィードバック**: C-7: SKILL.md が目標行数を超過

**変更内容**:
- **目的**: 性能推移テーブル生成とユーザー提示ロジックをテンプレート化
- **構造**:
```markdown
# 性能推移テーブル生成・プロンプト選択テンプレート

以下の手順でテーブルを生成し、AskUserQuestion でユーザーにプロンプトを選択させてください:

## パス変数
- `{knowledge_path}`: `.agent_bench/{agent_name}/knowledge.md` の絶対パス
- `{phase5_summary}`: Phase 5 のサブエージェント返答（7行サマリ）
- `{round_number}`: 現在のラウンド番号

## 手順

**Step 1: knowledge.md からスコアデータ取得**
- Read で `{knowledge_path}` を読み込む
- 「## ラウンド別スコア推移」セクションから過去ラウンドのスコアデータを取得する
- 各ラウンドについて: Baseline, Variant 1-N, Best, Δ from Initial を収集

**Step 2: 性能推移テーブル構築**
- 以下の構造でテーブルを生成する:
```
## 性能推移
| Round | Baseline | Variant 1 | Variant 2 | ... | Best | Δ from Initial |
|-------|----------|-----------|-----------|-----|------|----------------|
| R1    | X.X(SD) | X.X(SD)   | X.X(SD)   | ... | X.X  | +X.X           |
| ...   | ...      | ...       | ...       | ... | ...  | ...            |

初期スコア: {初期値} → 現在ベスト: {現在値} (改善: +{差分}pt, +{改善率}%)
全ラウンド最高スコア: {全ラウンドのBestの最大値} (Round {N}, {prompt_name})
```

**Step 3: プロンプト選択**
- AskUserQuestion でユーザーに提示する:
  - 性能推移テーブル
  - `{phase5_summary}` から推奨プロンプトと理由
  - 収束判定（該当する場合）
- 選択肢: 評価した全プロンプト名（ベースライン含む）を列挙。推奨プロンプトの選択肢に「(推奨)」を付記
- ユーザーの選択結果を以下の1行で返答する:
  ```
  selected_prompt: {prompt_name}
  ```
```
- **行数**: 約60行

### 4. templates/phase6-deploy.md（新規作成）
**対応フィードバック**: C-7: SKILL.md が目標行数を超過

**変更内容**:
- **目的**: プロンプトデプロイ手順をテンプレート化
- **構造**:
```markdown
# プロンプトデプロイテンプレート

以下の手順でプロンプトをデプロイしてください:

## パス変数
- `{selected_prompt_path}`: 選択されたプロンプトファイルの絶対パス
- `{agent_path}`: エージェント定義ファイルの絶対パス

## 手順

1. Read で `{selected_prompt_path}` を読み込む
2. ファイル先頭の `<!-- Benchmark Metadata ... -->` ブロックを除去する
   - 除去パターン: `<!-- Benchmark Metadata` から最初の `-->` までを削除
   - メタデータブロックが存在しない場合: そのまま次ステップへ
3. `{agent_path}` に Write で上書き保存する
4. 以下の1行を返答する:
   ```
   デプロイ完了: {agent_path}
   ```
```
- **行数**: 約30行

## 新規作成ファイル
| ファイル | 目的 | 対応フィードバック |
|---------|------|------------------|
| templates/phase0-perspective-resolution.md | perspective 検索・フォールバック処理の外部化 | C-7 |
| templates/phase6-performance-table.md | 性能推移テーブル生成とユーザー提示の外部化 | C-7 |
| templates/phase6-deploy.md | プロンプトデプロイ手順の外部化 | C-7 |

## 削除推奨ファイル
（該当なし）

## 実装順序
1. **templates/phase0-perspective-resolution.md 新規作成** — Phase 0 で参照するため最初に実施
2. **templates/phase6-performance-table.md 新規作成** — Phase 6 で参照するため実施
3. **templates/phase6-deploy.md 新規作成** — Phase 6 で参照するため実施
4. **SKILL.md 修正** — 新規テンプレートを参照する形に変更（Phase 0 → Phase 6 Step 1 → Phase 6 Step 1 デプロイの順）

依存関係の検出方法:
- 新規テンプレート作成（1-3）が完了してから SKILL.md（4）で参照を追加する
- テンプレート間の依存関係はないため、1-3は並列実行可能

## 注意事項
- 変更によって既存のワークフローが壊れないこと: 各テンプレートの返答形式を SKILL.md の期待値と一致させる
- テンプレート外部化の場合、SKILL.md の参照箇所も同時に更新すること: 実装順序4で反映
- 新規テンプレートのパス変数が SKILL.md で定義されていること: 実装順序4で全パス変数を明記する
- Phase 0 の perspective 解決テンプレートは失敗時にエラー返答する仕様（SKILL.md 側で自動生成フローにフォールバック）
- Phase 6 のテンプレートは AskUserQuestion を含むため、サブエージェントではなく親エージェントでの実行を推奨（または Phase 6-performance-table テンプレートのみサブエージェント委譲し、残りは親で実行）
