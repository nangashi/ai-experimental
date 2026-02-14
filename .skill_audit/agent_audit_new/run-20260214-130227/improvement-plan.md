# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | templates/collect-findings.md | 新規作成 | Phase 2 Step 1 の findings 収集サブエージェント用テンプレート | C-1 |
| 2 | SKILL.md | 修正 | Phase 2 Step 1 のインライン指示をテンプレート参照に置換 | C-1 |
| 3 | SKILL.md | 修正 | Phase 1 サブエージェント起動時に common-rules 内容をプロンプトに埋め込む | I-1 |
| 4 | agents/evaluator/criteria-effectiveness.md | 修正 | common-rules.md への参照削除（親から埋め込まれるため不要） | I-1 |
| 5 | agents/evaluator/scope-alignment.md | 修正 | common-rules.md への参照削除（親から埋め込まれるため不要） | I-1 |
| 6 | agents/evaluator/detection-coverage.md | 修正 | common-rules.md への参照削除（親から埋め込まれるため不要） | I-1 |
| 7 | agents/producer/workflow-completeness.md | 修正 | common-rules.md への参照削除（親から埋め込まれるため不要） | I-1 |
| 8 | agents/producer/output-format.md | 修正 | common-rules.md への参照削除（親から埋め込まれるため不要） | I-1 |
| 9 | agents/shared/instruction-clarity.md | 修正 | common-rules.md への参照削除（親から埋め込まれるため不要） | I-1 |
| 10 | agents/unclassified/scope-alignment.md | 修正 | common-rules.md への参照削除（親から埋め込まれるため不要） | I-1 |
| 11 | templates/collect-findings.md | 修正 | 返答フォーマットを件数のみに変更、詳細はファイル保存に変更 | I-2 |
| 12 | SKILL.md | 修正 | Phase 2 Step 1 の返答処理を変更（件数のみ取得、詳細はファイルから読み込み） | I-2 |
| 13 | SKILL.md | 修正 | Phase 2 Step 4 にサブエージェント失敗時のエラーハンドリングを追加 | I-3 |

## 変更ステップ

### Step 1: C-1: Phase 2 Step 1 における長いインライン指示
**対象ファイル**: templates/collect-findings.md（新規）, SKILL.md
**変更内容**:
- templates/collect-findings.md: Phase 2 Step 1 のサブエージェント用テンプレートを新規作成（SKILL.md 行182-196 のインライン指示を移行）
- SKILL.md 行181-196: インラインプロンプトをテンプレート参照形式に置換（`.claude/skills/agent_audit_new/templates/collect-findings.md` を Read で読み込み、その内容に従って処理を実行する形式）

### Step 2: I-1: Phase 1 サブエージェントの common-rules.md 参照の重複
**対象ファイル**: SKILL.md, agents/evaluator/criteria-effectiveness.md, agents/evaluator/scope-alignment.md, agents/evaluator/detection-coverage.md, agents/producer/workflow-completeness.md, agents/producer/output-format.md, agents/shared/instruction-clarity.md, agents/unclassified/scope-alignment.md
**変更内容**:
- SKILL.md 行140-160（Phase 1 サブエージェント起動部分）: 各次元サブエージェント起動時のプロンプトに common-rules.md の全内容を埋め込む形式に変更（例: `Read {dim_path} を読み込み、その内容に従って処理を実行してください。` → `以下の共通ルールを参照してください:\n\n{common-rules.md の全内容}\n\nRead {dim_path} を読み込み、その内容に従って処理を実行してください。`）
- agents/evaluator/criteria-effectiveness.md 行27: `Refer to `.claude/skills/agent_audit_new/agents/shared/common-rules.md` for the 2-phase approach details, severity rules, and adversarial thinking guidance.` → `The 2-phase approach, severity rules, and adversarial thinking guidance are provided in the prompt above.`
- agents/evaluator/criteria-effectiveness.md 行129: `See `.claude/skills/agent_audit_new/agents/shared/common-rules.md` for definitions.` → `See the severity definitions provided in the prompt.`
- agents/evaluator/scope-alignment.md 行25: 同様に参照削除（`The 2-phase approach, severity rules, and adversarial thinking guidance are provided in the prompt above.`）
- agents/evaluator/scope-alignment.md 行120: 同様に参照削除（`See the severity definitions provided in the prompt.`）
- agents/evaluator/detection-coverage.md 行18: 同様に参照削除
- agents/evaluator/detection-coverage.md 行143: 同様に参照削除
- agents/producer/workflow-completeness.md 行27: 同様に参照削除
- agents/producer/workflow-completeness.md 行144: 同様に参照削除
- agents/producer/output-format.md 行27: 同様に参照削除
- agents/producer/output-format.md 行150: 同様に参照削除
- agents/shared/instruction-clarity.md 行27: 同様に参照削除
- agents/shared/instruction-clarity.md 行157: 同様に参照削除
- agents/unclassified/scope-alignment.md 行17: 同様に参照削除
- agents/unclassified/scope-alignment.md 行94: 同様に参照削除

### Step 3: I-2: Phase 2 Step 1 の haiku サブエージェントの返答長制約不足
**対象ファイル**: templates/collect-findings.md, SKILL.md
**変更内容**:
- templates/collect-findings.md（Step 1 で作成済み）: 返答フォーマットを変更。件数のみを返答し、findings 詳細は `.agent_audit/{agent_name}/findings-summary.md` にテーブル形式で保存する指示に変更（返答フォーマット: `total: {N}\ncritical: {M}\nimprovement: {K}`）
- SKILL.md 行196-209: Phase 2 Step 1 の返答処理を変更。サブエージェント完了後、件数のみを取得し、findings 詳細表示用に `.agent_audit/{agent_name}/findings-summary.md` を Read で読み込む処理に変更

### Step 4: I-3: Phase 2 Step 4 のサブエージェント失敗時処理の欠落
**対象ファイル**: SKILL.md
**変更内容**:
- SKILL.md 行274-284（検証ステップ）: サブエージェント実行失敗検出処理を追加。Task ツールの返答から「エラー発生」または「適用失敗」を示すキーワード（例: `error:`, `failed:`, `skipped: all`）を検出し、失敗時は「✗ 改善適用失敗: {エラー概要}」を表示し、AskUserQuestion でリトライまたはロールバックの確認を追加（選択肢: リトライ/ロールバックして終了/強制的に検証ステップへ進む）

## 新規作成ファイル
| ファイル | 目的 | 対応 Step |
|---------|------|----------|
| templates/collect-findings.md | Phase 2 Step 1 の findings 収集サブエージェント用テンプレート（インライン指示の外部化 + 返答長制約強化） | Step 1, Step 3 |
| .agent_audit/{agent_name}/findings-summary.md | Phase 2 Step 1 で生成される findings 詳細テーブル（サブエージェントが保存、親が読み込み） | Step 3（実行時に自動生成） |

## 削除推奨ファイル
該当なし
