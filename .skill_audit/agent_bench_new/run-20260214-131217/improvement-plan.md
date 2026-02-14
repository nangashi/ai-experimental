# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 0 の perspective 自動生成ワークフロー（L83-111）をテンプレート参照に変更 | I-2 |
| 2 | SKILL.md | 修正 | Phase 1B の audit ファイルパス変数解決を「見つからない場合は変数を渡さない」に変更（L178） | I-3 |
| 3 | SKILL.md | 修正 | Phase 6 Step 1 の knowledge.md 読み込みを削除（L291） | I-1 |
| 4 | templates/phase1b-variant-generation.md | 修正 | audit パス変数の条件分岐記述を「パス変数の存在チェックのみ」に簡素化（L8-9） | I-3 |

## 変更ステップ

### Step 1: I-2: Phase 0 Step 3-5 の perspective 生成指示の外部化
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/SKILL.md, /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/templates/perspective/orchestrate-perspective-generation.md
**変更内容**:
- SKILL.md 行83-111: perspective 自動生成ワークフロー（Step 3-5）のインライン記述を削除し、テンプレート委譲に置換する
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
- templates/perspective/orchestrate-perspective-generation.md（新規作成）: 削除した Step 3-6 のワークフロー指示を記述する
  - Step 3: perspective 初期生成（generate-perspective.md テンプレート使用）
  - Step 4: 4並列批評（critic-*.md テンプレート使用）
  - Step 5: フィードバック統合・再生成（必要時のみ generate-perspective.md 再実行）
  - Step 6: 検証（必須セクション存在確認）
  - 返答フォーマット: 4行サマリ（generation_status, regeneration_needed, perspective_path, validation_result）

### Step 2: I-3: Phase 1B パス変数の条件記述の不統一
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/SKILL.md, /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/templates/phase1b-variant-generation.md
**変更内容**:
- SKILL.md 行178: audit ファイルパス変数の条件記述を「見つからない場合は変数を渡さない」に変更する
  ```markdown
  現在:
  - Glob で `.agent_audit/{agent_name}/audit-dim1-*.md` を検索し、見つかった場合は `{audit_dim1_path}` として渡す（見つからない場合は空文字列）。同様に `.agent_audit/{agent_name}/audit-dim2-*.md` を検索し `{audit_dim2_path}` として渡す

  変更後:
  - Glob で `.agent_audit/{agent_name}/audit-dim1-*.md` を検索し、見つかった場合は `{audit_dim1_path}` として渡す（見つからない場合は変数を渡さない）。同様に `.agent_audit/{agent_name}/audit-dim2-*.md` を検索し `{audit_dim2_path}` として渡す（見つからない場合は変数を渡さない）
  ```
- templates/phase1b-variant-generation.md 行8-9: 条件分岐記述を「パス変数の存在チェックのみ」に簡素化する
  ```markdown
  現在:
  - {audit_dim1_path} が指定されている場合かつパスが空文字列でない場合: Read で読み込む（agent_audit の基準有効性分析結果 — 改善推奨をバリアント生成の参考にする。ファイル不在時はスキップ）
  - {audit_dim2_path} が指定されている場合かつパスが空文字列でない場合: Read で読み込む（agent_audit のスコープ整合性分析結果 — スコープ改善をバリアント生成の参考にする。ファイル不在時はスキップ）

  変更後:
  - {audit_dim1_path} が指定されている場合: Read で読み込む（agent_audit の基準有効性分析結果 — 改善推奨をバリアント生成の参考にする）
  - {audit_dim2_path} が指定されている場合: Read で読み込む（agent_audit のスコープ整合性分析結果 — スコープ改善をバリアント生成の参考にする）
  ```

### Step 3: I-1: Phase 6 Step 1 の性能推移テーブルとレポート参照の重複
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/SKILL.md
**変更内容**:
- SKILL.md 行291: knowledge.md 読み込みを削除し、Phase 5 のレポートデータを直接使用する
  ```markdown
  現在（行289-306）:
  #### ステップ1: プロンプト選択とデプロイ

  `.agent_bench/{agent_name}/knowledge.md` を Read で読み込み、「ラウンド別スコア推移」セクションから過去ラウンドのスコアデータを取得する。Phase 5 のサブエージェント返答（7行サマリ）と合わせて、`AskUserQuestion` でユーザーに提示する:

  - **ラウンド別性能推移テーブル**:
  ...（省略）

  変更後:
  #### ステップ1: プロンプト選択とデプロイ

  Phase 5 のサブエージェント返答（7行サマリ）から、以下の情報を `AskUserQuestion` でユーザーに提示する:

  - deploy_info: ラウンド別性能推移テーブル（既に Phase 5 レポートに含まれている）
  - 推奨プロンプトとその推奨理由（reason）
  - 収束判定（convergence、該当する場合は「最適化が収束した可能性あり」を付記）
  ```
  - Phase 5 の 7行サマリの deploy_info フィールドには既にラウンド別性能推移テーブルが含まれているため、knowledge.md の読み込みは不要

## 新規作成ファイル
| ファイル | 目的 | 対応 Step |
|---------|------|----------|
| templates/perspective/orchestrate-perspective-generation.md | Phase 0 の perspective 自動生成ワークフロー（Step 3-6）を外部化 | Step 1 |

## 削除推奨ファイル
（該当なし）
