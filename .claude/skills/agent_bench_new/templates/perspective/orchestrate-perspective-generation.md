# perspective 自動生成オーケストレーション

以下の手順で perspective を自動生成してください。

## パス変数
- `{agent_name}`: Phase 0 で決定した値
- `{agent_path}`: エージェント定義ファイルの絶対パス
- `{user_requirements}`: Step 1 で構成したテキスト
- `{reference_perspective_path}`: Step 2 で取得したパス
- `{perspective_save_path}`: `.agent_bench/{agent_name}/perspective-source.md` の絶対パス

## 手順

### Step 3: perspective 初期生成

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_bench_new/templates/perspective/generate-perspective.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{agent_path}`: {agent_path}
- `{user_requirements}`: {user_requirements}
- `{perspective_save_path}`: {perspective_save_path}
- `{reference_perspective_path}`: {reference_perspective_path}

### Step 4: 批判レビュー（4並列）

以下の4つの `Task` を同一メッセージ内で並列起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

各エージェントへのプロンプト:
`.claude/skills/agent_bench_new/templates/perspective/{テンプレート名}` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{perspective_path}`: Step 3 で保存した perspective ファイルの絶対パス（{perspective_save_path}）
- `{agent_path}`: {agent_path}

| テンプレート | 焦点 |
|-------------|------|
| `critic-effectiveness.md` | 品質寄与度 + 他観点との境界 |
| `critic-completeness.md` | 網羅性 + 未考慮事項検出 + 問題バンク |
| `critic-clarity.md` | 表現明確性 + AI動作一貫性 |
| `critic-generality.md` | 汎用性 + 業界依存性フィルタ |

### Step 5: フィードバック統合・再生成

- 4件の批評から「重大な問題」「改善提案」を分類する
- 重大な問題または改善提案がある場合: フィードバックを `{user_requirements}` に追記し、Step 3 と同じパターンで perspective を再生成する（1回のみ）
- 改善不要の場合: 現行 perspective を維持する

### Step 6: 検証

- 生成された perspective を Read し、必須セクション（`## 概要`, `## 評価スコープ`, `## スコープ外`, `## ボーナス/ペナルティの判定指針`, `## 問題バンク`）の存在を確認する
- 検証成功 → perspective 解決完了
- 検証失敗 → エラー出力してスキルを終了する

## 返答フォーマット

以下の4行フォーマットで結果のみ返答する:
```
generation_status: {initial/regenerated}
regeneration_needed: {yes/no}
perspective_path: {perspective_save_path}
validation_result: {success/failed}
```
