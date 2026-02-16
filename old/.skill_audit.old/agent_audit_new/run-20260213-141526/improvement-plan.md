# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | 全テンプレート参照パスを `agent_bench` から `agent_bench_new` に修正 | C-1: スキルディレクトリパス誤記 |
| 2 | SKILL.md | 修正 | 成果物セクションの追加、Phase 0 の user_requirements 受け渡し追加、Phase 0 perspective 検証追加、Phase 3/4/5 の SD = N/A 処理追加、Phase 0 Step 4 返答フォーマット明記、Phase 0 Step 5 再生成スキップ条件明記、Phase 6 並列実行変更 | C-2, C-3, I-3, I-5, I-7, I-9, I-6 |
| 3 | templates/phase6a-knowledge-update.md | 修正 | 再実行時の累計ラウンド数と効果テーブル更新で冪等性確保のための条件分岐追加 | I-1: 冪等性 - knowledge.md の累計ラウンド数と効果テーブルの更新で再実行時の競合リスク |
| 4 | templates/phase6b-proven-techniques-update.md | 修正 | 再実行時のエントリ重複防止のための条件分岐明示 | I-2: 冪等性 - proven-techniques.md の更新で再実行時のエントリ重複リスク |
| 5 | templates/phase2-test-document.md | 修正 | 初回実行時の knowledge.md 空状態での動作明記 | I-4: Phase 2 の knowledge.md 参照が Phase 1A のみで実行される場合に機能しない |
| 6 | templates/phase4-scoring.md | 修正 | SD = N/A 時の処理を明記 | I-5: Phase 3 失敗時の SD = N/A 処理が Phase 4/5 で参照されていない |
| 7 | templates/phase5-analysis-report.md | 修正 | SD = N/A 時の処理を明記 | I-5: Phase 3 失敗時の SD = N/A 処理が Phase 4/5 で参照されていない |
| 8 | templates/phase1b-variant-generation.md | 修正 | audit パス変数が空文字列の場合の処理を明記 | I-8: Phase 1B の audit パス変数が空文字列の場合の処理が未定義 |
| 9 | templates/phase1a-variant-generation.md | 修正 | user_requirements パス変数の追加（既存だが不足している場合の対応） | C-3: データフロー妥当性 - Phase 0 の user_requirements が Phase 1A に渡されない |

## 各ファイルの変更詳細

### 1. /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/SKILL.md（修正）
**対応フィードバック**: C-1: スキルディレクトリパス誤記

**変更内容**:
- 行83, 94, 126, 129, 148, 152-154, 168, 176-178, 190, 192-193, 255, 257, 278, 280, 330, 341, 344: `.claude/skills/agent_bench/` → `.claude/skills/agent_bench_new/`

### 2. /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/SKILL.md（修正）
**対応フィードバック**: C-2, C-3, I-3, I-5, I-7, I-9, I-6

**変更内容**:

- **行8-16 付近（使い方セクション直後）**: 「## 期待される成果物」セクションを追加
  ```markdown
  ## 期待される成果物

  - `.agent_bench/{agent_name}/perspective-source.md` - 評価観点定義（問題バンクを含む）
  - `.agent_bench/{agent_name}/perspective.md` - 評価観点定義（問題バンク除外版）
  - `.agent_bench/{agent_name}/knowledge.md` - エージェント固有の性能改善知見
  - `.agent_bench/{agent_name}/prompts/v{NNN}-*.md` - 各ラウンドのプロンプトバリアント
  - `.agent_bench/{agent_name}/test-document-round-{NNN}.md` - テスト入力文書
  - `.agent_bench/{agent_name}/answer-key-round-{NNN}.md` - 正解キー
  - `.agent_bench/{agent_name}/results/v{NNN}-{name}-run{R}.md` - 評価実行結果
  - `.agent_bench/{agent_name}/results/v{NNN}-{name}-scoring.md` - 採点結果
  - `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md` - ラウンド別比較レポート
  - `{agent_path}` - デプロイ済み最適化プロンプト（エージェント定義ファイル）
  - `.claude/skills/agent_bench_new/proven-techniques.md` - エージェント横断の実証済みテクニック（自動更新）
  ```

- **行64 付近（パースペクティブ自動生成スキップ条件）**: 既存ファイル検証ステップを追加
  ```markdown
  既に `.agent_bench/{agent_name}/perspective-source.md` が存在する場合:
  - Read で読み込み、必須セクション（`## 概要`, `## 評価スコープ`, `## スコープ外`, `## ボーナス/ペナルティの判定指針`, `## 問題バンク`）の存在を確認する
  - 検証成功: 既存ファイルを使用し、自動生成をスキップする
  - 検証失敗: 既存ファイルを削除し、自動生成を実行する
  ```

- **行92-104 付近（Step 4 批評レビュー）**: 返答フォーマットを明記
  ```markdown
  **Step 4: 批判レビュー（4並列）**
  以下の4つの `Task` を同一メッセージ内で並列起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

  各エージェントへのプロンプト:
  `.claude/skills/agent_bench_new/templates/perspective/{テンプレート名}` を Read で読み込み、その内容に従って処理を実行してください。
  パス変数:
  - `{perspective_path}`: Step 3 で保存した perspective ファイルの絶対パス
  - `{agent_path}`: エージェント定義ファイルの絶対パス

  各サブエージェントは SendMessage で「## 重大な問題」「## 改善提案」セクションを含む形式で報告する。
  ```

- **行106-109 付近（Step 5 再生成スキップ条件）**: 判定基準を明示
  ```markdown
  **Step 5: フィードバック統合・再生成**
  - 4件の批評から「重大な問題」「改善提案」を分類する
  - 4件の批評の全てに「## 重大な問題」セクションの項目が0件の場合: 再生成をスキップし、現行 perspective を維持する
  - それ以外の場合: フィードバックを `{user_requirements}` に追記し、Step 3 と同じパターンで perspective を再生成する（1回のみ）
  ```

- **行148-159 付近（Phase 1A パス変数リスト）**: user_requirements パス変数を追加
  ```markdown
  パス変数:
  - `{agent_path}`: エージェント定義ファイルの絶対パス（存在しない場合は「新規」と指定）
  - `{prompts_dir}`: `.agent_bench/{agent_name}/prompts` の絶対パス
  - `{approach_catalog_path}`: `.claude/skills/agent_bench_new/approach-catalog.md` の絶対パス
  - `{proven_techniques_path}`: `.claude/skills/agent_bench_new/proven-techniques.md` の絶対パス
  - `{perspective_source_path}`: `.agent_bench/{agent_name}/perspective-source.md` の絶対パス
  - `{perspective_path}`: `.agent_bench/{agent_name}/perspective.md` の絶対パス
  - `{agent_name}`: Phase 0 で決定した値
  - エージェント定義が新規作成の場合、またはエージェント定義が既存だが不足している場合:
    - `{user_requirements}`: Phase 0 で収集した要件テキスト（空文字列の場合あり）
  ```

- **行238 付近（Phase 3 SD = N/A 処理）**: Phase 4/5 への影響を明記
  ```markdown
  - **成功数 < 総数 かつ、各プロンプトに最低1回の成功結果がある**: 警告を出力し Phase 4 へ進む（採点は成功した Run のみで実施。Run が1回のみのプロンプトは SD = N/A とする。Phase 4/5 テンプレートは SD = N/A の場合の処理ルールに従う）
  ```

- **行322-349 付近（Phase 6 ステップ2）**: 並列実行に変更
  ```markdown
  #### ステップ2: ナレッジ更新・スキル知見フィードバック・次アクション選択

  以下の2つのサブエージェントを並列起動する（A と B は独立しているため同時実行可能）:

  **A) ナレッジ更新サブエージェント**

  `Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

  `.claude/skills/agent_bench_new/templates/phase6a-knowledge-update.md` を Read で読み込み、その内容に従って処理を実行してください。
  パス変数:
  - `{knowledge_path}`: `.agent_bench/{agent_name}/knowledge.md` の絶対パス
  - `{report_save_path}`: `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md`
  - `{recommended_name}`, `{judgment_reason}`: Phase 5 のサブエージェント返答の recommended と reason

  **B) スキル知見フィードバックサブエージェント**

  `Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

  `.claude/skills/agent_bench_new/templates/phase6b-proven-techniques-update.md` を Read で読み込み、その内容に従って処理を実行してください。
  パス変数:
  - `{proven_techniques_path}`: `.claude/skills/agent_bench_new/proven-techniques.md` の絶対パス
  - `{knowledge_path}`: `.agent_bench/{agent_name}/knowledge.md` の絶対パス
  - `{report_save_path}`: `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md`
  - `{agent_name}`: Phase 0 で決定した値

  両方のサブエージェント完了後、次のステップへ進む。

  **C) 次アクション選択（親で実行）**

  （以降同じ）
  ```

### 3. /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/templates/phase6a-knowledge-update.md（修正）
**対応フィードバック**: I-1: 冪等性 - knowledge.md の累計ラウンド数と効果テーブルの更新で再実行時の競合リスク

**変更内容**:
- 行8-14: 累計ラウンド数と効果テーブル更新のルールに冪等性確保の条件分岐を追加
  ```markdown
  現在の記述:
     - 累計ラウンド数を +1
     - 初期スコアが未測定の場合、今回のベースラインスコアを初期スコアとして記録する
     - 効果的だったバリアントの変化 → 「効果が確認された構造変化」テーブルに追記
     - 同等以下だったバリアントの変化 → 「効果が限定的/逆効果」テーブルに追記
     - 「バリエーションステータス」テーブルで、今回検証したバリエーション ID の Status を EFFECTIVE/INEFFECTIVE/MARGINAL に更新し、Round と Effect を記入する
     - 「テストセット履歴」に今回のラウンドのエントリを追記
     - 「ラウンド別スコア推移」テーブルに今回のラウンドのエントリ（各プロンプトの Mean(SD)、Best スコア、Δ from Initial）を追記する

  改善後の記述:
     - 累計ラウンド数を +1（ただし、現在のラウンド番号が既にknowledge.md内のラウンド別スコア推移テーブルに存在する場合は更新のみ行う）
     - 初期スコアが未測定の場合、今回のベースラインスコアを初期スコアとして記録する
     - 効果的だったバリアントの変化 → 「効果が確認された構造変化」テーブルに追記（ただし、同一ラウンド・同一バリエーションIDのエントリが既存の場合は上書き）
     - 同等以下だったバリアントの変化 → 「効果が限定的/逆効果だった構造変化」テーブルに追記（ただし、同一ラウンド・同一バリエーションIDのエントリが既存の場合は上書き）
     - 「バリエーションステータス」テーブルで、今回検証したバリエーション ID の Status を EFFECTIVE/INEFFECTIVE/MARGINAL に更新し、Round と Effect を記入する（既存エントリの場合は上書き）
     - 「テストセット履歴」に今回のラウンドのエントリを追記（ただし、同一ラウンド番号のエントリが既存の場合は上書き）
     - 「ラウンド別スコア推移」テーブルに今回のラウンドのエントリ（各プロンプトの Mean(SD)、Best スコア、Δ from Initial）を追記する（ただし、同一ラウンド番号のエントリが既存の場合は上書き）
  ```

### 4. /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/templates/phase6b-proven-techniques-update.md（修正）
**対応フィードバック**: I-2: 冪等性 - proven-techniques.md の更新で再実行時のエントリ重複リスク

**変更内容**:
- 行28-44: 昇格対象の統合ルールに冪等性確保の条件分岐を明示
  ```markdown
  現在の記述:
     **統合ルール（preserve + integrate）**:
     - 既存エントリは削除しない。矛盾するエビデンスがある場合は Section 3 へ移動する
     - 既存エントリと同じテクニックの場合: 効果範囲を拡大し、出典列を更新する
     - 新規エントリの場合: 該当セクションの末尾に追加する
     - 出典列の形式: `{agent1}:{rounds}, {agent2}:{rounds}` (例: `sec:16,perf:4`)

  改善後の記述:
     **統合ルール（preserve + integrate）**:
     - 既存エントリは削除しない。矛盾するエビデンスがある場合は Section 3 へ移動する
     - 同一テクニック名かつ同一エージェント名の組み合わせが既存エントリに存在する場合: 既存エントリの効果範囲と出典列を更新する（ラウンド番号をマージする。例: `sec:16` + Round 18 → `sec:16,18`）。重複ラウンド番号は除去する
     - 同一テクニック名だが異なるエージェント名の場合: 既存エントリの効果範囲を拡大し、出典列に新規エージェント名とラウンド番号を追加する
     - 新規テクニック名の場合: 該当セクションの末尾に追加する
     - 出典列の形式: `{agent1}:{rounds}, {agent2}:{rounds}` (例: `sec:16,perf:4`)
  ```

### 5. /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/templates/phase2-test-document.md（修正）
**対応フィードバック**: I-4: Phase 2 の knowledge.md 参照が Phase 1A のみで実行される場合に機能しない

**変更内容**:
- 行6 付近: knowledge.md 参照時の初回条件を明記
  ```markdown
  現在の記述:
     - {knowledge_path} （過去の知見 — テスト対象文書履歴を確認し、過去と異なるドメインを選択する）

  改善後の記述:
     - {knowledge_path} （過去の知見 — テスト対象文書履歴を確認し、過去と異なるドメインを選択する。テストセット履歴が存在しない場合は初回として任意のドメインを選択する）
  ```

### 6. /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/templates/phase4-scoring.md（修正）
**対応フィードバック**: I-5: Phase 3 失敗時の SD = N/A 処理が Phase 4/5 で参照されていない

**変更内容**:
- 行5-7 付近: SD = N/A 時の処理ルールを追加
  ```markdown
  現在の記述:
  4. Read で {result_run1_path} （Run1結果）と {result_run2_path} （Run2結果）を読み込む
  5. 採点基準の検出判定基準とスコア計算式に従い、各結果を採点する

  改善後の記述:
  4. Read で {result_run1_path} （Run1結果）を読み込む。{result_run2_path} （Run2結果）が存在する場合は読み込む（Phase 3 で Run2 が失敗した場合は存在しない）
  5. 採点基準の検出判定基準とスコア計算式に従い、各結果を採点する。Run2 が存在しない場合は SD = N/A とする
  ```

### 7. /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/templates/phase5-analysis-report.md（修正）
**対応フィードバック**: I-5: Phase 3 失敗時の SD = N/A 処理が Phase 4/5 で参照されていない

**変更内容**:
- 行10-11 付近: SD = N/A 時の推奨判定ルールを追加
  ```markdown
  現在の記述:
  4. 比較レポートを生成して {report_save_path} に保存する。必要なセクション:
     - 実行条件、比較対象、スコアマトリクス（問題別検出+ボーナス/ペナルティ詳細）、スコアサマリ、推奨判定、考察（独立変数ごとの効果分析、次回への示唆）

  改善後の記述:
  4. 比較レポートを生成して {report_save_path} に保存する。必要なセクション:
     - 実行条件、比較対象、スコアマトリクス（問題別検出+ボーナス/ペナルティ詳細）、スコアサマリ、推奨判定、考察（独立変数ごとの効果分析、次回への示唆）
     - SD = N/A のプロンプトが存在する場合: Mean スコアのみで比較し、推奨判定の理由に「SD計測不可のため Mean のみで判定」と付記する
  ```

### 8. /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/templates/phase1b-variant-generation.md（修正）
**対応フィードバック**: I-8: Phase 1B の audit パス変数が空文字列の場合の処理が未定義

**変更内容**:
- 行18-19 付近: audit パス変数が空の場合の処理を明記
  ```markdown
  現在の記述:
     - {audit_dim1_path} が指定されている場合（空文字列でない場合）: Read で読み込む（基準有効性分析結果 — 改善推奨をバリアント生成の参考にする）
     - {audit_dim2_path} が指定されている場合（空文字列でない場合）: Read で読み込む（スコープ整合性分析結果 — スコープ改善をバリアント生成の参考にする）

  改善後の記述:
     - {audit_dim1_path} が空文字列でない場合: Read で読み込む（基準有効性分析結果 — 改善推奨をバリアント生成の参考にする）
     - {audit_dim2_path} が空文字列でない場合: Read で読み込む（スコープ整合性分析結果 — スコープ改善をバリアント生成の参考にする）
     - 両方とも空文字列の場合: knowledge.md の知見のみに基づいてバリアント生成を行う
  ```

### 9. /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/templates/phase1a-variant-generation.md（修正）
**対応フィードバック**: C-3: データフロー妥当性 - Phase 0 の user_requirements が Phase 1A に渡されない

**変更内容**:
- 行4-6 付近: user_requirements パス変数を追加
  ```markdown
  現在の記述:
  1. Read で以下のファイルを読み込む:
     - {proven_techniques_path} （実証済みテクニック — ベースライン構築ガイドを含む）
     - {approach_catalog_path} （アプローチカタログ — 共通ルール・推奨構成・改善戦略を含む）
     - {perspective_source_path} （パースペクティブ — 評価スコープと問題バンクを含む）

  改善後の記述:
  1. Read で以下のファイルを読み込む:
     - {proven_techniques_path} （実証済みテクニック — ベースライン構築ガイドを含む）
     - {approach_catalog_path} （アプローチカタログ — 共通ルール・推奨構成・改善戦略を含む）
     - {perspective_source_path} （パースペクティブ — 評価スコープと問題バンクを含む）
  ```

- 行7-9 付近: エージェント定義不足時の user_requirements 参照を追加
  ```markdown
  現在の記述:
  2. エージェント定義ファイル {agent_path} を Read で確認する:
     - 存在すれば、その内容をベースライン（比較基準）とする
     - 存在しなければ: {user_requirements} を基に、proven-techniques.md の「ベースライン構築ガイド」に従って生成する。アプローチカタログの推奨構成を参考にする。指示文は英語で記述し、テーブル/マトリクス構造を活用する

  改善後の記述:
  2. エージェント定義ファイル {agent_path} を Read で確認する:
     - 存在すれば、その内容をベースライン（比較基準）とする。ただし、{user_requirements} が空文字列でない場合は、エージェント定義の不足部分を補うための追加要件として参照する
     - 存在しなければ: {user_requirements} を基に、proven-techniques.md の「ベースライン構築ガイド」に従って生成する。アプローチカタログの推奨構成を参考にする。指示文は英語で記述し、テーブル/マトリクス構造を活用する
  ```

## 新規作成ファイル
なし

## 削除推奨ファイル
なし

## 実装順序
1. **SKILL.md（パス修正のみ）** - C-1 対応。全テンプレート参照パスを `agent_bench` から `agent_bench_new` に修正。これを最初に実施することで、以降のテンプレート参照が正しく動作する。
2. **templates/phase1a-variant-generation.md** - C-3 対応。Phase 0 からの user_requirements 受け渡しを追加。
3. **templates/phase1b-variant-generation.md** - I-8 対応。audit パス変数が空の場合の処理を明記。
4. **templates/phase2-test-document.md** - I-4 対応。初回実行時の knowledge.md 空状態での動作を明記。
5. **templates/phase4-scoring.md** - I-5 対応。SD = N/A 時の処理ルールを追加。
6. **templates/phase5-analysis-report.md** - I-5 対応。SD = N/A 時の推奨判定ルールを追加。Phase 4 の変更後に実施。
7. **templates/phase6a-knowledge-update.md** - I-1 対応。冪等性確保の条件分岐を追加。
8. **templates/phase6b-proven-techniques-update.md** - I-2 対応。冪等性確保の条件分岐を明示。
9. **SKILL.md（機能追加）** - C-2, I-3, I-7, I-9, I-6 対応。成果物セクション追加、perspective 検証追加、返答フォーマット明記、再生成スキップ条件明記、並列実行変更。全テンプレートの変更が完了した後に実施し、ワークフロー全体の整合性を確保。

## 注意事項
- SKILL.md のパス修正（C-1）を最初に実施しないと、テンプレート参照が失敗する
- Phase 1A テンプレートの user_requirements 追加（C-3）は、SKILL.md の Phase 1A パス変数リスト更新と同時に行う必要がある
- Phase 4/5 テンプレートの SD = N/A 処理（I-5）は両方同時に実施し、一貫性を保つ
- Phase 6A/6B テンプレートの冪等性確保（I-1, I-2）は独立しているため、どちらを先に実施してもよい
- SKILL.md の機能追加（C-2, I-3, I-7, I-9, I-6）は最後に実施し、全テンプレート変更後にワークフロー全体を最終調整する
