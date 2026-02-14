# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | 冒頭にスキルの成功基準を明記、Phase 0の分岐処理を明確化、Phase 1B の audit ファイル検索を直接 Read に変更、Phase 3/4/5 のエラー処理を明確化、Phase 6 の判定処理を明確化 | C-1, C-2, C-4, C-7, I-3, I-4, I-7, I-8, I-9 |
| 2 | templates/phase1a-variant-generation.md | 修正 | {user_requirements} 未定義時の処理を明記 | C-3 |
| 3 | templates/phase1b-variant-generation.md | 修正 | audit ファイルパスが空文字列の場合の処理を明記 | C-1 |
| 4 | templates/phase2-test-document.md | 修正 | perspective.md に問題バンクを含める設計に変更、perspective-source.md の読み込みを削除 | C-5 |
| 5 | templates/phase6a-knowledge-update.md | 修正 | バックアップをディレクトリ管理に変更、最新10件のみ保持 | I-5 |
| 6 | templates/phase6b-proven-techniques-update.md | 修正 | AskUserQuestion を削除し、親の責務として移管 | I-2 |
| 7 | templates/perspective/verify-perspective.md | 新規作成 | perspective 検証をサブエージェントに委譲 | C-6 |
| 8 | templates/phase0-pattern-detection.md | 新規作成 | ファイル名パターン判定ロジックを外部化 | I-1 |
| 9 | templates/phase0-feedback-integration.md | 新規作成 | 批評統合ロジックを外部化、TaskUpdate の metadata 受信処理を含む | I-1, I-6 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**: C-1, C-2, C-4, C-7, I-3, I-4, I-7, I-8, I-9

**変更内容**:
- **行5-6（C-7）**: 現在の記述 → 改善後の記述
  ```markdown
  <!-- 現在 -->
  エージェント定義ファイル（mdファイル）を新規作成または既存改善し、テストに対する性能を反復的に比較評価して最適化します。各ラウンドで得られた知見を `knowledge.md` に蓄積し、反復的に改善します。

  <!-- 改善後 -->
  エージェント定義ファイル（mdファイル）を新規作成または既存改善し、テストに対する性能を反復的に比較評価して最適化します。各ラウンドで得られた知見を `knowledge.md` に蓄積し、反復的に改善します。

  **成功基準**: エージェント定義ファイルの改善版と性能評価レポート（knowledge.md）を生成し、収束または指定ラウンド数完了まで反復します。
  ```

- **行48-57（C-2, I-1）**: ファイル名パターン判定ロジックをテンプレート化
  ```markdown
  <!-- 現在 -->
  4. perspective ファイルを以下の順序で検索する:
     a. `.agent_bench/{agent_name}/perspective-source.md` を Read で確認する
     b. 見つからない場合、ファイル名（拡張子なし）が `{key}-{target}-reviewer` パターンに一致するか判定する:
        - `*-design-reviewer` → `{key}` = `-design-reviewer` の前の部分, `{target}` = `design`
        - `*-code-reviewer` → `{key}` = `-code-reviewer` の前の部分, `{target}` = `code`
        - 一致した場合: `.claude/skills/agent_bench_new/perspectives/{target}/{key}.md` を Read で確認する
        - 見つかった場合: `.agent_bench/{agent_name}/perspective-source.md` に Write でコピーする
        - 一致したがファイル不在の場合: パースペクティブ自動生成（後述）を実行する
     c. パターン不一致の場合: パースペクティブ自動生成（後述）を実行する

  <!-- 改善後 -->
  4. perspective ファイルを以下の順序で検索する:
     a. `.agent_bench/{agent_name}/perspective-source.md` を Read で確認する
     b. 見つからない場合、Task ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:
        `.claude/skills/agent_bench_new/templates/phase0-pattern-detection.md` を Read で読み込み、その内容に従って処理を実行してください。
        パス変数:
        - `{agent_name}`: Phase 0 で決定した値
        - `{agent_path}`: エージェント定義ファイルの絶対パス
        - `{perspective_source_path}`: `.agent_bench/{agent_name}/perspective-source.md` の絶対パス

        返答:
        - `found: yes` — perspective ファイルが見つかりコピー完了
        - `found: no` — perspective ファイル不在、自動生成が必要

     c. 返答が `found: no` の場合: パースペクティブ自動生成（後述）を実行する
  ```

- **行108-115（I-1, I-6）**: 批評統合ロジックをテンプレート化
  ```markdown
  <!-- 現在 -->
  **Step 5: フィードバック統合・再生成**
  各批評エージェントは以下の形式で SendMessage で報告する:
  - 重大な問題: {あればリスト、なければ「なし」}
  - 改善提案: {あればリスト、なければ「なし」}

  4件の批評を受信後:
  - 4件の批評のうち1件以上で「重大な問題」フィールドが空でない場合: フィードバックを `{user_requirements}` に追記し、Step 3 と同じパターンで perspective を再生成する（1回のみ）
  - すべての批評で「重大な問題」が「なし」の場合: 現行 perspective を維持する

  <!-- 改善後 -->
  **Step 5: フィードバック統合・再生成**
  各批評エージェントは TaskUpdate で自分のタスクを completed に更新し、metadata に以下を設定する:
  - `critical_issues`: 重大な問題リスト（なければ空配列）
  - `improvements`: 改善提案リスト（なければ空配列）

  4件の批評タスクの完了を待ち、Task ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

  `.claude/skills/agent_bench_new/templates/phase0-feedback-integration.md` を Read で読み込み、その内容に従って処理を実行してください。
  パス変数:
  - `{task_ids}`: 4件の批評タスク ID（カンマ区切り）
  - `{user_requirements}`: Step 1 で構成したテキスト
  - `{perspective_save_path}`: `.agent_bench/{agent_name}/perspective-source.md` の絶対パス
  - `{agent_path}`, `{reference_perspective_path}`: Step 3 で使用した値

  返答:
  - `regenerated: yes` — 重大な問題が検出され再生成完了
  - `regenerated: no` — 問題なし、現行 perspective を維持
  ```

- **行113-115（I-4）**: 再生成後の処理フローを明確化
  ```markdown
  <!-- 現在 -->
  4件の批評を受信後:
  - 4件の批評のうち1件以上で「重大な問題」フィールドが空でない場合: フィードバックを `{user_requirements}` に追記し、Step 3 と同じパターンで perspective を再生成する（1回のみ）
  - すべての批評で「重大な問題」が「なし」の場合: 現行 perspective を維持する

  <!-- 改善後 -->
  フィードバック統合サブエージェントの返答に応じて:
  - `regenerated: yes` の場合:
    - 再度 Step 4 の批評を実行する
    - 再生成後も重大な問題が残る場合: 警告を出力し、AskUserQuestion で「継続（条件付き）」「中断」を選択
  - `regenerated: no` の場合: Step 6 へ進む
  ```

- **行117-120（C-6）**: perspective 検証をサブエージェントに委譲
  ```markdown
  <!-- 現在 -->
  **Step 6: 検証**
  - 生成された perspective を Read し、必須セクション（`## 概要`, `## 評価スコープ`, `## スコープ外`, `## ボーナス/ペナルティの判定指針`, `## 問題バンク`）の存在を確認する
  - 検証成功 → perspective 解決完了
  - 検証失敗 → エラー出力してスキルを終了する

  <!-- 改善後 -->
  **Step 6: 検証**
  Task ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

  `.claude/skills/agent_bench_new/templates/perspective/verify-perspective.md` を Read で読み込み、その内容に従って処理を実行してください。
  パス変数:
  - `{perspective_path}`: `.agent_bench/{agent_name}/perspective-source.md` の絶対パス

  返答:
  - `valid: yes` — 検証成功
  - `valid: no` — 検証失敗

  検証失敗の場合: エラー出力してスキルを終了する
  ```

- **行61（C-5）**: perspective.md に問題バンクを含める設計に変更
  ```markdown
  <!-- 現在 -->
  5. perspective が見つかった場合（検索または自動生成で取得）:
     - `{perspective_source_path}` = `.agent_bench/{agent_name}/perspective-source.md` の絶対パス
     - perspective-source.md から「## 問題バンク」セクション以降を除いた内容を `.agent_bench/{agent_name}/perspective.md` に Write で保存する（作業コピー。Phase 4 採点バイアス防止のため問題バンクは含めない）

  <!-- 改善後 -->
  5. perspective が見つかった場合（検索または自動生成で取得）:
     - `{perspective_source_path}` = `.agent_bench/{agent_name}/perspective-source.md` の絶対パス
     - perspective-source.md の内容をそのまま `.agent_bench/{agent_name}/perspective.md` に Write で保存する（作業コピー）
  ```

- **行188-190（C-1, I-3, I-9）**: Phase 1B の audit ファイル検索を直接 Read に変更
  ```markdown
  <!-- 現在 -->
  - Glob で `.agent_audit/{agent_name}/audit-*.md` を検索し、見つかった全ファイルのうち:
    - 基準有効性分析（audit-ce-*.md または audit-dim1-*.md）の最新ファイルを {audit_dim1_path} として渡す。最新ファイルはファイル名の run タイムスタンプまたは更新日時で判定する。見つからない場合は空文字列を渡し、Phase 1B は knowledge.md の過去知見のみでバリアント生成を行う
    - スコープ整合性分析（audit-sa-*.md または audit-dim2-*.md）の最新ファイルを {audit_dim2_path} として渡す。最新ファイルはファイル名の run タイムスタンプまたは更新日時で判定する。見つからない場合は空文字列を渡し、Phase 1B は knowledge.md の過去知見のみでバリアント生成を行う

  <!-- 改善後 -->
  - audit ファイルを直接パスで Read を試行する:
    - `.agent_audit/{agent_name}/audit-ce-approved.md` を Read 試行 → 成功なら {audit_dim1_path} に設定、失敗なら空文字列
    - `.agent_audit/{agent_name}/audit-sa-approved.md` を Read 試行 → 成功なら {audit_dim2_path} に設定、失敗なら空文字列
    - パスが空文字列の場合、テンプレート側で knowledge.md の過去知見のみでバリアント生成を行う
  ```

- **行243, 249-252（C-4）**: Phase 3 再試行時の Run 番号割り当てを明確化
  ```markdown
  <!-- 現在 -->
  - `{R}`: Run 番号（1 または 2）。各プロンプトの1回目実行を Run1、2回目実行を Run2 として結果ファイル名を生成する。並列起動時は各サブエージェントが受け取ったパラメータの Run 番号をそのまま使用する（競合なし）

  全サブエージェント完了後、成功数を集計し分岐する:
  ...
  - **いずれかのプロンプトで成功結果が0回**: `AskUserQuestion` で確認する
    - **再試行**: 失敗したタスクのみ再実行する（1回のみ）

  <!-- 改善後 -->
  - `{R}`: Run 番号（1 または 2）。各プロンプトの1回目実行を Run1、2回目実行を Run2 として結果ファイル名を生成する。並列起動時は各サブエージェントが受け取ったパラメータの Run 番号をそのまま使用する（競合なし）

  全サブエージェント完了後、成功数を集計し分岐する:
  ...
  - **いずれかのプロンプトで成功結果が0回**: `AskUserQuestion` で確認する
    - **再試行**: 失敗したタスクを元の Run 番号で再実行する（Run1 失敗ならば Run1 で再実行）。再失敗時は当該 Run を欠損とみなし、Phase 4 で SD=N/A として処理する
  ```

- **行277-280（I-7）**: Phase 4 ベースライン失敗判定を明確化
  ```markdown
  <!-- 現在 -->
  - **一部失敗**: `AskUserQuestion` で確認する
    - **再試行**: 失敗した採点タスクのみ再実行する（1回のみ）
    - **失敗プロンプトを除外して続行**: 成功したプロンプトのみで Phase 5 へ進む（ベースラインが失敗した場合は中断）

  <!-- 改善後 -->
  - **一部失敗**: 失敗プロンプト名に "baseline" を含むか判定する
    - ベースライン失敗の場合: エラー出力して中断
    - ベースライン成功の場合: `AskUserQuestion` で確認
      - **再試行**: 失敗した採点タスクのみ再実行する（1回のみ）
      - **失敗プロンプトを除外して続行**: 成功したプロンプトのみで Phase 5 へ進む
  ```

- **行295（I-8）**: Phase 5 返答行数検証の失敗処理を明確化
  ```markdown
  <!-- 現在 -->
  サブエージェント完了後:
  - **成功**: サブエージェントの返答が7行（recommended, reason, convergence, scores, variants, deploy_info, user_summary）の形式であることを確認する。不一致の場合は1回リトライする。確認成功後、返答をテキスト出力してユーザーに提示し、Phase 6 へ進む

  <!-- 改善後 -->
  サブエージェント完了後:
  - **成功**: サブエージェントの返答が7行（recommended, reason, convergence, scores, variants, deploy_info, user_summary）の形式であることを確認する
    - 不一致の場合: 返答内容をログ出力し、「返答が7行形式（key: value）でありません。フォーマットを修正して再生成してください」とフィードバックして1回リトライする
    - 確認成功後、返答をテキスト出力してユーザーに提示し、Phase 6 へ進む
  ```

### 2. templates/phase1a-variant-generation.md（修正）
**対応フィードバック**: C-3

**変更内容**:
- **行2-9**: {user_requirements} 未定義時の処理を明記
  ```markdown
  <!-- 現在 -->
  1. Read で以下のファイルを読み込む:
     ...
  2. エージェント定義ファイル {agent_path} を Read で確認する:
     - 存在すれば、その内容をベースライン（比較基準）とする
     - 存在しなければ: {user_requirements} を基に、proven-techniques.md の「ベースライン構築ガイド」に従って生成する。アプローチカタログの推奨構成を参考にする。指示文は英語で記述し、テーブル/マトリクス構造を活用する

  <!-- 改善後 -->
  1. Read で以下のファイルを読み込む:
     ...
  2. エージェント定義ファイル {agent_path} を Read で確認する:
     - 存在すれば、その内容をベースライン（比較基準）とする
     - 存在しなければ:
       - {user_requirements} が渡されている場合: それを基に、proven-techniques.md の「ベースライン構築ガイド」に従って生成する
       - {user_requirements} が渡されていない場合: {agent_path} の内容をベースとしてベースラインを生成する
       - アプローチカタログの推奨構成を参考にする。指示文は英語で記述し、テーブル/マトリクス構造を活用する
  ```

### 3. templates/phase1b-variant-generation.md（修正）
**対応フィードバック**: C-1

**変更内容**:
- **行7-8**: audit ファイルパスが空文字列の場合の処理を明記
  ```markdown
  <!-- 現在 -->
  1. Read で以下のファイルを読み込む:
     ...
     - {audit_dim1_path} が空でない場合: Read で読み込む（agent_audit の基準有効性分析結果 — 改善推奨をバリアント生成の参考にする）
     - {audit_dim2_path} が空でない場合: Read で読み込む（agent_audit のスコープ整合性分析結果 — スコープ改善をバリアント生成の参考にする）

  <!-- 改善後 -->
  1. Read で以下のファイルを読み込む:
     ...
     - {audit_dim1_path} を確認する:
       - パスが空文字列でない場合: Read で読み込む（agent_audit の基準有効性分析結果 — 改善推奨をバリアント生成の参考にする）
       - パスが空文字列の場合: audit 結果なしとしてスキップし、knowledge.md の過去知見のみでバリアント生成を行う
     - {audit_dim2_path} を確認する:
       - パスが空文字列でない場合: Read で読み込む（agent_audit のスコープ整合性分析結果 — スコープ改善をバリアント生成の参考にする）
       - パスが空文字列の場合: audit 結果なしとしてスキップし、knowledge.md の過去知見のみでバリアント生成を行う
  ```

### 4. templates/phase2-test-document.md（修正）
**対応フィードバック**: C-5

**変更内容**:
- **行1-7**: perspective-source.md の読み込みを削除、perspective.md に問題バンクを含める設計に変更
  ```markdown
  <!-- 現在 -->
  以下の手順でテスト対象文書と正解キーを生成してください:

  1. Read で以下のファイルを読み込む:
     - {test_document_guide_path} （テスト対象文書生成ガイド — 入力型判定と文書構成を含む）
     - {perspective_path} （観点定義 — 問題バンクを含まない作業コピー）
     - {perspective_source_path} （観点定義ソース — 問題バンクを含む。テスト文書の問題埋め込み時に参考にする）
     - {knowledge_path} （過去の知見 — テスト対象文書履歴を確認し、過去と異なるドメインを選択する）
  2. test-document-guide.md のセクション1に従い、perspective.md の概要からエージェントの入力型を判定する
  3. 入力型に応じたテスト対象文書を生成する
  4. test-document-guide.md の問題埋め込みガイドラインに従い、perspective ソースの問題バンクを参考に問題を自然に埋め込む

  <!-- 改善後 -->
  以下の手順でテスト対象文書と正解キーを生成してください:

  1. Read で以下のファイルを読み込む:
     - {test_document_guide_path} （テスト対象文書生成ガイド — 入力型判定と文書構成を含む）
     - {perspective_path} （観点定義 — 問題バンクを含む）
     - {knowledge_path} （過去の知見 — テスト対象文書履歴を確認し、過去と異なるドメインを選択する）
  2. test-document-guide.md のセクション1に従い、perspective.md の概要からエージェントの入力型を判定する
  3. 入力型に応じたテスト対象文書を生成する
  4. test-document-guide.md の問題埋め込みガイドラインに従い、perspective.md の問題バンクを参考に問題を自然に埋め込む
  ```

- **SKILL.md の Phase 2 パラメータも変更**:
  ```markdown
  <!-- SKILL.md 行206-208 -->
  <!-- 現在 -->
  - `{perspective_path}`: `.agent_bench/{agent_name}/perspective.md` の絶対パス
  - `{perspective_source_path}`: `.agent_bench/{agent_name}/perspective-source.md` の絶対パス（問題バンクを含む）

  <!-- 改善後 -->
  - `{perspective_path}`: `.agent_bench/{agent_name}/perspective.md` の絶対パス（問題バンクを含む）
  ```

### 5. templates/phase6a-knowledge-update.md（修正）
**対応フィードバック**: I-5

**変更内容**:
- **行1-5**: バックアップをディレクトリ管理に変更
  ```markdown
  <!-- 現在 -->
  以下の手順で knowledge.md を更新してください:

  1. {knowledge_path} を Read で読み込む
  2. 読み込んだ内容を {knowledge_path}.backup-{timestamp}.md に Write で保存する（timestamp は YYYYMMDD-HHMMSS 形式）
  3. バックアップ完了を確認してから更新処理に進む

  <!-- 改善後 -->
  以下の手順で knowledge.md を更新してください:

  1. {knowledge_path} を Read で読み込む
  2. バックアップディレクトリを作成（存在しなければ）: `mkdir -p {knowledge_path のディレクトリ}/backups`
  3. 読み込んだ内容を `{knowledge_path のディレクトリ}/backups/knowledge-{timestamp}.md` に Write で保存する（timestamp は YYYYMMDD-HHMMSS 形式）
  4. Bash で `ls -t {knowledge_path のディレクトリ}/backups/knowledge-*.md | tail -n +11 | xargs -r rm` を実行し、古いバックアップを削除（最新10件のみ保持）
  5. バックアップ完了を確認してから更新処理に進む
  ```

### 6. templates/phase6b-proven-techniques-update.md（修正）
**対応フィードバック**: I-2

**変更内容**:
- **行45-48**: AskUserQuestion を削除
  ```markdown
  <!-- 現在 -->
  5. 更新内容をユーザーに提示し、AskUserQuestion で承認を得る:
     - 提示内容: Tier 1/2/3 への昇格対象テクニック、追加される効果データ、変更される一般化原則
     - 選択肢: 「承認して更新」「キャンセル」
     - 承認された場合のみ Write を実行する
  6. Write で {proven_techniques_path} に保存する（承認時のみ）
  7. 以下のフォーマットで確認のみ返答する:

  <!-- 改善後 -->
  5. 更新内容をサマリとして返答する（親が AskUserQuestion でユーザーに確認する）:
     - 返答フォーマット（複数行）:
       ```
       update_summary:
       - Tier 1 昇格: N件（テクニックリスト）
       - Tier 2 昇格: M件（テクニックリスト）
       - Section 3 移動: K件（テクニックリスト）
       ```
  6. 親からの承認指示を受けた場合のみ、Write で {proven_techniques_path} に保存する
  7. 以下のフォーマットで確認のみ返答する:
  ```

- **SKILL.md の Phase 6 Step 2B も変更**（行353-375 付近）:
  ```markdown
  <!-- 現在 -->
  **B) スキル知見フィードバックサブエージェント**

  `Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

  `.claude/skills/agent_bench_new/templates/phase6b-proven-techniques-update.md` を Read で読み込み、その内容に従って処理を実行してください。
  パス変数:
  - `{proven_techniques_path}`: `.claude/skills/agent_bench_new/proven-techniques.md` の絶対パス
  - `{knowledge_path}`: `.agent_bench/{agent_name}/knowledge.md` の絶対パス
  - `{report_save_path}`: `.agent_bench/{agent_name}/reports/round-{round_number}-comparison.md`
  - `{agent_name}`: Phase 0 で決定した値

  <!-- 改善後 -->
  **B) スキル知見フィードバック**

  B-1) 更新候補の抽出（サブエージェント）:

  `Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

  `.claude/skills/agent_bench_new/templates/phase6b-proven-techniques-update.md` を Read で読み込み、その内容に従って処理を実行してください。
  パス変数:
  - `{proven_techniques_path}`: `.claude/skills/agent_bench_new/proven-techniques.md` の絶対パス
  - `{knowledge_path}`: `.agent_bench/{agent_name}/knowledge.md` の絶対パス
  - `{report_save_path}`: `.agent_bench/{agent_name}/reports/round-{round_number}-comparison.md`
  - `{agent_name}`: Phase 0 で決定した値

  サブエージェント完了後、返答に `update_summary` が含まれる場合:

  B-2) ユーザー承認（親で実行）:

  `AskUserQuestion` で更新内容を提示し、承認を得る:
  - 提示内容: サブエージェントの `update_summary`
  - 選択肢: 「承認して更新」「キャンセル」

  承認された場合のみ、サブエージェントに「承認されました。更新を実行してください」と指示する
  （注: サブエージェント再実行の実装詳細は Phase 6 実装時に検討）
  ```

### 7. templates/perspective/verify-perspective.md（新規作成）
**対応フィードバック**: C-6

**変更内容**: 新規ファイル作成
```markdown
以下の手順で perspective ファイルを検証してください:

1. Read で {perspective_path} を読み込む
2. 必須セクションの存在を確認する:
   - `## 概要`
   - `## 評価スコープ`
   - `## スコープ外`
   - `## ボーナス/ペナルティの判定指針`
   - `## 問題バンク`
3. 以下のフォーマットで返答する（1行のみ）:

valid: {yes / no}
```

### 8. templates/phase0-pattern-detection.md（新規作成）
**対応フィードバック**: I-1

**変更内容**: 新規ファイル作成
```markdown
以下の手順でファイル名パターン判定と perspective ファイル検索を行ってください:

1. {agent_name} のファイル名（拡張子なし）が `{key}-{target}-reviewer` パターンに一致するか判定する:
   - `*-design-reviewer` → `{key}` = `-design-reviewer` の前の部分, `{target}` = `design`
   - `*-code-reviewer` → `{key}` = `-code-reviewer` の前の部分, `{target}` = `code`
2. パターンに一致した場合:
   - `.claude/skills/agent_bench_new/perspectives/{target}/{key}.md` を Read で確認する
   - ファイルが存在する場合: {perspective_source_path} に Write でコピーし、`found: yes` を返答
   - ファイルが存在しない場合: `found: no` を返答
3. パターンに一致しない場合: `found: no` を返答

返答フォーマット（1行のみ）:
found: {yes / no}
```

### 9. templates/phase0-feedback-integration.md（新規作成）
**対応フィードバック**: I-1, I-6

**変更内容**: 新規ファイル作成
```markdown
以下の手順で批評フィードバックを統合し、必要に応じて perspective を再生成してください:

1. TaskGet ツールで {task_ids}（カンマ区切り）の各タスクを取得する
2. 各タスクの metadata から以下を抽出する:
   - `critical_issues`: 重大な問題リスト
   - `improvements`: 改善提案リスト
3. 4件の批評のうち1件以上で `critical_issues` が空でない（空配列でない）場合:
   a. フィードバックを {user_requirements} に追記する:
      ```
      ## 批評フィードバック
      {critical_issues と improvements をマージして記述}
      ```
   b. `.claude/skills/agent_bench_new/templates/perspective/generate-perspective.md` を Read で読み込み、その内容に従って perspective を再生成する
      パス変数:
      - {agent_path}, {user_requirements} (更新済み), {perspective_save_path}, {reference_perspective_path}
   c. `regenerated: yes` を返答
4. すべての批評で `critical_issues` が空の場合:
   - `regenerated: no` を返答

返答フォーマット（1行のみ）:
regenerated: {yes / no}
```

## 新規作成ファイル
| ファイル | 目的 | 対応フィードバック |
|---------|------|------------------|
| templates/perspective/verify-perspective.md | perspective 検証をサブエージェントに委譲し、親コンテキストから perspective 全文を削除 | C-6 |
| templates/phase0-pattern-detection.md | ファイル名パターン判定ロジックを外部化し、SKILL.md の可読性を向上 | I-1 |
| templates/phase0-feedback-integration.md | 批評統合ロジックを外部化し、TaskUpdate の metadata 受信処理を含む | I-1, I-6 |

## 削除推奨ファイル
（なし）

## 実装順序
1. **templates/perspective/verify-perspective.md（新規作成）** — Phase 0 Step 6 で参照されるため最初に作成
2. **templates/phase0-pattern-detection.md（新規作成）** — Phase 0 Step 4 で参照されるため2番目に作成
3. **templates/phase0-feedback-integration.md（新規作成）** — Phase 0 Step 5 で参照されるため3番目に作成
4. **templates/phase1a-variant-generation.md（修正）** — 独立した修正（他ファイルへの依存なし）
5. **templates/phase1b-variant-generation.md（修正）** — 独立した修正（他ファイルへの依存なし）
6. **templates/phase2-test-document.md（修正）** — perspective.md 構造変更に依存するため、SKILL.md の Phase 0 修正後に実施
7. **templates/phase6a-knowledge-update.md（修正）** — 独立した修正（他ファイルへの依存なし）
8. **templates/phase6b-proven-techniques-update.md（修正）** — SKILL.md の Phase 6 Step 2B 修正と連携
9. **SKILL.md（修正）** — 最後に実施（新規テンプレート3件、修正テンプレート5件への参照を含むため）

依存関係の検出方法:
- 新規テンプレート作成（1-3）→ SKILL.md でのテンプレート参照追加（9）→ 1-3が先
- templates/phase2-test-document.md（6）は SKILL.md の Phase 0（perspective.md 構造変更）に依存 → SKILL.md が先
- templates/phase6b-proven-techniques-update.md（8）は SKILL.md の Phase 6 Step 2B と連携 → 同時修正

## 注意事項
- 変更によって既存のワークフローが壊れないこと
- テンプレート外部化の場合、SKILL.md の参照箇所も同時に更新すること
- 新規テンプレートのパス変数が SKILL.md で定義されていること
- Phase 0 の perspective.md 生成方式の変更（問題バンクを含める）により、Phase 2/4 のテンプレートが影響を受けるため、変更の伝播を確認すること
- Phase 6 Step 2B の AskUserQuestion 移管により、親とサブエージェント間の通信パターンが変更されるため、実装時に注意すること
