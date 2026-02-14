以下の手順で perspective を自動生成してください:

## パス変数
- `{agent_path}`: エージェント定義ファイルの絶対パス
- `{agent_name}`: エージェント名（agent_name導出ルールで決定）
- `{perspective_save_path}`: `.agent_bench/{agent_name}/perspective-source.md` の絶対パス

## 手順

### Step 1: 要件抽出
- エージェント定義ファイルの内容（目的、評価基準、入力/出力の型、スコープ情報）を `{user_requirements}` として構成する
- エージェント定義が実質空または不足がある場合: `AskUserQuestion` で以下をヒアリングし `{user_requirements}` に追加する
  - エージェントの目的・役割
  - 想定される入力と期待される出力
  - 使用ツール・制約事項

### Step 2: 既存 perspective の参照データ収集
- `.claude/skills/agent_bench_new/perspectives/design/*.md` を Glob で列挙する
- 最初に見つかったファイルを `{reference_perspective_path}` として使用する（構造とフォーマットの参考用）
- 見つからない場合は `{reference_perspective_path}` を空とする

### Step 3: perspective 初期生成

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_bench_new/templates/perspective/generate-perspective.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{agent_path}`: エージェント定義ファイルの絶対パス
- `{user_requirements}`: Step 1 で構成したテキスト
- `{perspective_save_path}`: `.agent_bench/{agent_name}/perspective-source.md` の絶対パス
- `{reference_perspective_path}`: Step 2 で取得したパス

### Step 4: 批判レビュー（4並列）

以下の4つの `Task` を同一メッセージ内で並列起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

各エージェントは批評レポートをサブエージェント返答として返す。

各エージェントへのプロンプト:
`.claude/skills/agent_bench_new/templates/perspective/{テンプレート名}` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{perspective_path}`: `.agent_bench/{agent_name}/perspective-source.md` の絶対パス
- `{agent_path}`: エージェント定義ファイルの絶対パス
- `{task_id}`: 各批評サブエージェントのタスクID

| テンプレート | 焦点 |
|-------------|------|
| `critic-effectiveness.md` | 品質寄与度 + 他観点との境界 |
| `critic-completeness.md` | 網羅性 + 未考慮事項検出 + 問題バンク |
| `critic-clarity.md` | 表現明確性 + AI動作一貫性 |
| `critic-generality.md` | 汎用性 + 業界依存性フィルタ |

### Step 5: フィードバック統合・再生成

1. 4つのサブエージェントの返答から「重大な問題」「改善提案」を分類する
2. 重大な問題または改善提案がある場合:
   - フィードバックを `{user_requirements}` に追記する
   - Step 3 と同じパターンで perspective を再生成する（1回のみ）
3. 改善不要の場合: 現行 perspective を維持する

### Step 6: 検証

1. 生成された perspective を Read し、必須セクション（`## 概要`, `## 評価スコープ`, `## スコープ外`, `## ボーナス/ペナルティの判定指針`, `## 問題バンク`）の存在を確認する
2. 検証成功 → perspective 解決完了
3. 検証失敗 → エラー出力してスキルを終了する

## 返答フォーマット
最後に以下の1行のみ返答してください:
```
perspective_generated: {perspective_save_path}
```
