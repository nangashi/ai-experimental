# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 0 Step 4 批評の出力先を明示化 | I-1 |
| 2 | SKILL.md | 修正 | Phase 0 Step 4 パス変数リストに {task_id} を追加 | I-2 |
| 3 | templates/phase1b-variant-generation.md | 修正 | Step 3 ベースラインコピー保存時に上書き動作を明記 | I-3 |
| 4 | templates/phase2-test-document.md | 修正 | Step 6 保存時に上書き動作を明記 | I-4 |
| 5 | SKILL.md | 修正 | Phase 6 Step 2-A knowledge.md検証位置を移動 | I-5 |
| 6 | SKILL.md | 修正 | Phase 0 Step 4b フォールバック失敗時の処理を明記 | I-6 |
| 7 | templates/phase3-evaluation.md | 新規作成 | Phase 3 評価タスク指示をテンプレート外部化 | I-7 |
| 8 | SKILL.md | 修正 | Phase 3 評価タスクをテンプレート委譲パターンに変更 | I-7 |
| 9 | templates/phase0-perspective-generation.md | 新規作成 | Phase 0 perspective 自動生成をテンプレート外部化 | I-8 |
| 10 | SKILL.md | 修正 | Phase 0 perspective 自動生成をテンプレート委譲パターンに変更 | I-8 |

## 変更ステップ

### Step 1: I-1: 出力先の決定性: Phase 0 perspective批評の出力先が未定義
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/SKILL.md

**変更内容**:
- 行95-108: 現在の記述「各エージェントへのプロンプト:」 → 「各エージェントは批評レポートをサブエージェント返答として返す。」を追加
- 行112: 現在の記述「1. 4件の批評から「重大な問題」「改善提案」を分類する」 → 「1. 4つのサブエージェントの返答から「重大な問題」「改善提案」を分類する」

### Step 2: I-2: 参照整合性: SKILL.md未定義の変数がテンプレートで使用
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/SKILL.md

**変更内容**:
- 行100-101: 現在の記述「パス変数:\n- `{perspective_path}`: `.agent_bench/{agent_name}/perspective-source.md` の絶対パス\n- `{agent_path}`: エージェント定義ファイルの絶対パス」 → 「パス変数:\n- `{perspective_path}`: `.agent_bench/{agent_name}/perspective-source.md` の絶対パス\n- `{agent_path}`: エージェント定義ファイルの絶対パス\n- `{task_id}`: 各批評サブエージェントのタスクID」

### Step 3: I-3: 冪等性: Phase 1B ベースラインコピーの重複保存
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/templates/phase1b-variant-generation.md

**変更内容**:
- 行16: 現在の記述「3. ベースライン（比較用コピー）を {prompts_dir}/v{NNN}-baseline.md として保存する（NNN = 累計ラウンド数 + 1）」 → 「3. ベースライン（比較用コピー）を {prompts_dir}/v{NNN}-baseline.md として保存する（NNN = 累計ラウンド数 + 1）。既存ファイルが存在する場合は上書きする」

### Step 4: I-4: 冪等性: Phase 2 テスト文書生成の重複保存
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/templates/phase2-test-document.md

**変更内容**:
- 行12-14: 現在の記述「6. Write で以下を保存する:\n   - {test_document_save_path}\n   - {answer_key_save_path}」 → 「6. Write で以下を保存する（既存ファイルが存在する場合は上書き）:\n   - {test_document_save_path}\n   - {answer_key_save_path}」

### Step 5: I-5: データフロー妥当性: Phase 6 Step 2-A knowledge.md検証の位置不整合
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/SKILL.md

**変更内容**:
- 行315-343: Phase 6 Step 2-Aサブエージェント起動指示（行315-325）の**後**、かつ Step 2-B/2-C起動指示（行344以降）の**前**に、現在 行327-342 にある「A-1) knowledge.md 構造検証」セクションを移動する

変更後の順序:
```
#### ステップ2: ナレッジ更新・スキル知見フィードバック・次アクション選択

**まず** ナレッジ更新を実行し完了を待つ:

**A) ナレッジ更新サブエージェント**

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_bench_new/templates/phase6a-knowledge-update.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{knowledge_path}`: `.agent_bench/{agent_name}/knowledge.md` の絶対パス
- `{report_save_path}`: `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md`
- `{recommended_name}`, `{judgment_reason}`: Phase 5 のサブエージェント返答の recommended と reason

← **ここでサブエージェント完了を待つ**

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

**B) スキル知見フィードバックサブエージェント**
...
```

### Step 6: I-6: エッジケース処理適正化: Phase 0 Step 4b reviewerパターンフォールバック失敗時の処理欠落
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/SKILL.md

**変更内容**:
- 行58-60: 現在の記述「- 一致した場合: `.claude/skills/agent_bench_new/perspectives/{target}/{key}.md` を Read で確認する\n      - 見つかった場合: `.agent_bench/{agent_name}/perspective-source.md` に Write でコピーする\n   c. いずれも見つからない場合: パースペクティブ自動生成（後述）を実行する」 → 「- 一致した場合: `.claude/skills/agent_bench_new/perspectives/{target}/{key}.md` を Read で確認する\n      - 見つかった場合: `.agent_bench/{agent_name}/perspective-source.md` に Write でコピーする\n      - 見つからなかった場合: Step 4c（パースペクティブ自動生成）に進む\n   c. パターンに一致しなかった場合、またはフォールバック検索でファイルが存在しなかった場合: パースペクティブ自動生成（後述）を実行する」

### Step 7: I-7: Phase 3 インライン指示のテンプレート外部化
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/templates/phase3-evaluation.md, /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/SKILL.md

**変更内容**:
- templates/phase3-evaluation.md（新規作成）: 以下の内容を作成
```markdown
以下の手順でエージェント定義を評価してください:

1. Read で {prompt_path} を読み込み、その内容に従ってタスクを実行してください
2. Read で {test_doc_path} を読み込み、処理対象としてください
3. 処理結果を Write で {result_path} に保存してください
4. 最後に「保存完了: {result_path}」とだけ返答してください

## パス変数
- `{prompt_path}`: 評価対象プロンプトの絶対パス
- `{test_doc_path}`: テスト対象文書の絶対パス
- `{result_path}`: 評価結果の保存先パス
```

- SKILL.md 行221-230: 現在のインライン指示 → テンプレート委譲パターンに変更
```markdown
各サブエージェントへの指示:

`.claude/skills/agent_bench_new/templates/phase3-evaluation.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{prompt_path}`: 評価対象プロンプトの絶対パス
- `{test_doc_path}`: `.agent_bench/{agent_name}/test-document-round-{NNN}.md`
- `{result_path}`: `.agent_bench/{agent_name}/results/v{NNN}-{name}-run{R}.md`
```

### Step 8: I-8: Phase 0 perspective 自動生成の指示長
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/templates/phase0-perspective-generation.md, /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/SKILL.md

**変更内容**:
- templates/phase0-perspective-generation.md（新規作成）: SKILL.md 行68-117（約50行）の perspective 自動生成手順を以下の構造で外部化
```markdown
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
（SKILL.md 行118以降の内容を継承）

## 返答フォーマット
最後に以下の1行のみ返答してください:
```
perspective_generated: {perspective_save_path}
```
```

- SKILL.md 行68-117: 現在の詳細記述 → テンプレート委譲パターンに簡略化
```markdown
### 4c. パースペクティブ自動生成

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_bench_new/templates/phase0-perspective-generation.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{agent_path}`: エージェント定義ファイルの絶対パス
- `{agent_name}`: エージェント名（agent_name導出ルールで決定）
- `{perspective_save_path}`: `.agent_bench/{agent_name}/perspective-source.md` の絶対パス
```

## 新規作成ファイル
| ファイル | 目的 | 対応 Step |
|---------|------|----------|
| /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/templates/phase3-evaluation.md | Phase 3 評価タスク指示のテンプレート外部化 | Step 7 |
| /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/templates/phase0-perspective-generation.md | Phase 0 perspective 自動生成のテンプレート外部化 | Step 8 |

## 削除推奨ファイル
（該当なし）
