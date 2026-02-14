# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 0 Step 3-6: perspective自動生成の直接制御化（オーケストレーター除去） | I-1 |
| 2 | SKILL.md | 修正 | Phase 6 Step 2-A: knowledge.md更新後の構造検証ステップ追加 | I-2 |

## 変更ステップ

### Step 1: I-1: Phase 0 perspective自動生成の委譲粒度
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/SKILL.md

**変更内容**:
- L83-92: 現在の2段階委譲構造を直接制御に変更

現在の記述（L83-92）:
```markdown
**Step 3-6: perspective 自動生成ワークフロー実行**
`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_bench_new/templates/perspective/orchestrate-perspective-generation.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{agent_name}`: Phase 0 で決定した値
- `{agent_path}`: エージェント定義ファイルの絶対パス
- `{user_requirements}`: Step 1 で構成したテキスト
- `{reference_perspective_path}`: Step 2 で取得したパス
- `{perspective_save_path}`: `.agent_bench/{agent_name}/perspective-source.md` の絶対パス
```

改善後の記述:
```markdown
**Step 3: perspective 初期生成**

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_bench_new/templates/perspective/generate-perspective.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{agent_path}`: エージェント定義ファイルの絶対パス
- `{user_requirements}`: Step 1 で構成したテキスト
- `{perspective_save_path}`: `.agent_bench/{agent_name}/perspective-source.md` の絶対パス
- `{reference_perspective_path}`: Step 2 で取得したパス

**Step 4: 批判レビュー（4並列）**

以下の4つの `Task` を同一メッセージ内で並列起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

各エージェントへのプロンプト:
`.claude/skills/agent_bench_new/templates/perspective/{テンプレート名}` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{perspective_path}`: `.agent_bench/{agent_name}/perspective-source.md` の絶対パス
- `{agent_path}`: エージェント定義ファイルの絶対パス

| テンプレート | 焦点 |
|-------------|------|
| `critic-effectiveness.md` | 品質寄与度 + 他観点との境界 |
| `critic-completeness.md` | 網羅性 + 未考慮事項検出 + 問題バンク |
| `critic-clarity.md` | 表現明確性 + AI動作一貫性 |
| `critic-generality.md` | 汎用性 + 業界依存性フィルタ |

**Step 5: フィードバック統合・再生成**

1. 4件の批評から「重大な問題」「改善提案」を分類する
2. 重大な問題または改善提案がある場合:
   - フィードバックを `{user_requirements}` に追記する
   - Step 3 と同じパターンで perspective を再生成する（1回のみ）
3. 改善不要の場合: 現行 perspective を維持する

**Step 6: 検証**

1. 生成された perspective を Read し、必須セクション（`## 概要`, `## 評価スコープ`, `## スコープ外`, `## ボーナス/ペナルティの判定指針`, `## 問題バンク`）の存在を確認する
2. 検証成功 → perspective 解決完了して Phase 0 の共通処理へ
3. 検証失敗 → エラー出力してスキルを終了する
```

### Step 2: I-2: 欠落ステップ: 最終成果物の構造検証
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/SKILL.md

**変更内容**:
- L286-295: Phase 6 Step 2-A のナレッジ更新サブエージェント呼び出し後に検証ステップを追加

現在の記述（L286-295）:
```markdown
**A) ナレッジ更新サブエージェント**

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_bench_new/templates/phase6a-knowledge-update.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{knowledge_path}`: `.agent_bench/{agent_name}/knowledge.md` の絶対パス
- `{report_save_path}`: `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md`
- `{recommended_name}`, `{judgment_reason}`: Phase 5 のサブエージェント返答の recommended と reason

**次に** 以下の2つを同時に実行する:
```

改善後の記述:
```markdown
**A) ナレッジ更新サブエージェント**

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_bench_new/templates/phase6a-knowledge-update.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{knowledge_path}`: `.agent_bench/{agent_name}/knowledge.md` の絶対パス
- `{report_save_path}`: `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md`
- `{recommended_name}`, `{judgment_reason}`: Phase 5 のサブエージェント返答の recommended と reason

**A-1) knowledge.md 構造検証**

1. `.agent_bench/{agent_name}/knowledge.md` を Read で読み込む
2. 以下の必須セクションの存在を確認する:
   - `## 累計ラウンド数`
   - `## 初期スコア`
   - `## 効果が確認された構造変化`
   - `## 効果が限定的/逆効果だった変化`
   - `## バリエーションステータス`
   - `## テストセット履歴`
   - `## ラウンド別スコア推移`
   - `## 最新ラウンドサマリ`
   - `## 改善のための考慮事項`
3. 検証結果:
   - 全セクション存在 → 次のステップへ
   - 欠落あり → エラー出力して中断（欠落セクション名を明記）

**次に** 以下の2つを同時に実行する:
```

## 新規作成ファイル
（該当なし）

## 削除推奨ファイル
| ファイル | 理由 | 対応 Step |
|---------|------|----------|
| templates/perspective/orchestrate-perspective-generation.md | 親が直接制御する設計に変更したため不要 | Step 1 |
