# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 6 Step 2 の並列実行順序を明確化、Phase 0 にパス変数定義追加、Phase 1A/1B に存在確認追加、Phase 2/4 にエラーメッセージ改善、Phase 3 の処理をテンプレート化、エージェント目的ヒアリング条件を明示、Phase 0 エラーメッセージ改善 | C-1, C-2, C-3, C-5, I-1, I-2, I-3, I-4, I-8 |
| 2 | templates/phase0-perspective-generation.md | 修正 | 返答フォーマットに1行返答を明示 | I-5 |
| 3 | templates/perspective/critic-effectiveness.md | 修正 | 未定義変数 {existing_perspectives_summary} を削除 | C-2 |
| 4 | templates/perspective/critic-completeness.md | 修正 | 返答テーブルの行数制限を「exactly 5-8 rows」に明示 | I-6 |
| 5 | templates/phase1b-variant-generation.md | 修正 | audit ファイル読み込みに else 節を追加 | I-7 |
| 6 | templates/phase3-evaluation.md | 新規作成 | Phase 3 の並列評価実行指示を外部化 | I-1 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**:
- C-1 [effectiveness]: Phase 6 Step 2 の並列実行順序が不明確
- C-2 [stability]: 参照整合性: 未定義変数の使用
- C-3 [stability]: 冪等性: ファイル上書き前の存在確認なし
- C-5 [ux]: ユーザー確認欠落: Phase 0のエージェント目的ヒアリング条件が曖昧
- I-1 [architecture, ux, efficiency]: Phase 3 指示の埋め込み
- I-2 [architecture]: Phase 6 Step 2 の並列実行記述の曖昧さ
- I-3 [ux]: エラー通知: Phase 2失敗時の再試行回数制限が未通知
- I-4 [ux]: エラー通知: Phase 4失敗時の「ベースライン失敗時の中断」条件が不明確
- I-8 [ux]: エラー通知: Phase 0 perspective自動生成失敗時のメッセージに対処法がない

**変更内容**:

- **Phase 0 パス変数追加** (C-2):
  - 現在: Phase 0 の `phase0-perspective-resolution.md` への指示に、パス変数リストに `{existing_perspectives_summary}` が含まれていない
  - 改善: Phase 0 の 50-56 行目に以下のパス変数を追加:
    ```markdown
    - `{existing_perspectives_summary}`: Glob で `.claude/skills/agent_bench_new/perspectives/**/*.md` を列挙し、各ファイルのファイル名と最初の行を抽出した要約文字列（perspective 解決で使用）
    ```

- **Phase 0 エージェント目的ヒアリング条件の明示** (C-5):
  - 現在: 34-37 行目「引数から `agent_path` を取得する（未指定の場合は `AskUserQuestion` で確認）」のみで、ヒアリング実行条件が不明確
  - 改善: 34-42 行目を以下に差し替え:
    ```markdown
    1. 引数から `agent_path` を取得する（未指定の場合は `AskUserQuestion` で確認）
    2. Read で `agent_path` のファイルを読み込む
       - 読み込み失敗時: エラー出力して終了
       - ファイルが実質空（行数 < 10）または必要セクション不足の場合:
         - AskUserQuestion でエージェントの目的・役割、想定される入力と期待される出力、使用ツール・制約事項をヒアリングし、`{user_requirements}` としてメモリに保持する
         - Phase 0 の perspective 自動生成で `{user_requirements}` を参照する
    ```

- **Phase 0 perspective 自動生成失敗時のエラーメッセージ改善** (I-8):
  - 現在: 71 行目「サブエージェント失敗時: エラー内容を出力してスキルを終了する」のみ
  - 改善: 以下に差し替え:
    ```markdown
    サブエージェント失敗時: 以下のエラーメッセージを出力してスキルを終了する
    ```
    エラー: perspective 自動生成に失敗しました
    - 原因: {サブエージェントの失敗理由}
    - 対処法:
      1. エージェント定義ファイル ({agent_path}) に、目的・入力型・出力型を明確に記述する
      2. 既存の perspective ファイルを `.agent_bench/{agent_name}/perspective-source.md` に手動で配置する（例: .claude/skills/agent_bench_new/perspectives/design/security.md）
    ```
    ```

- **Phase 1A/1B 存在確認追加** (C-3):
  - 現在: 111 行目（Phase 1A）、133 行目（Phase 1B）で `{prompts_dir}` への Write 指示のみ
  - 改善: Phase 1A の 105-121 行目に以下を追加（Phase 1B も同様）:
    ```markdown
    サブエージェント実行前:
    - Glob で `{prompts_dir}/v{NNN}-*.md` を検索し、既存ファイルがある場合:
      - AskUserQuestion でユーザーに確認する
      - 選択肢: 「上書き / スキップして Phase 2 へ」
      - 「スキップ」の場合: Phase 1 をスキップして Phase 2 へ進む
    ```
    (Phase 1A の 105 行目直後、Phase 1B の 127 行目直後に挿入)

- **Phase 2 エラーメッセージ改善** (I-3):
  - 現在: 168-170 行目「サブエージェント失敗時: AskUserQuestion で「再試行 / 中断」を選択する」のみ
  - 改善: 以下に差し替え:
    ```markdown
    サブエージェント失敗時: AskUserQuestion で「再試行 / 中断」を選択する
    - エラーメッセージに「再試行は1回のみ可能です。2回目の失敗時は中断されます」を明記する
    - **再試行**: Phase 2 のサブエージェントを再実行（1回のみ）
    - **中断**: エラー内容を出力してスキルを終了する
    ```

- **Phase 3 処理のテンプレート化** (I-1):
  - 現在: 192-199 行目に各サブエージェントへの指示が直接埋め込まれている
  - 改善: 以下に差し替え:
    ```markdown
    各サブエージェントへの指示: `.claude/skills/agent_bench_new/templates/phase3-evaluation.md` を Read で読み込み、その内容に従って処理を実行してください。
    パス変数:
    - `{prompt_path}`: 評価対象プロンプトの絶対パス
    - `{test_doc_path}`: `.agent_bench/{agent_name}/test-document-round-{NNN}.md`
    - `{result_path}`: `.agent_bench/{agent_name}/results/v{NNN}-{name}-run{R}.md`
    - `{NNN}`: プロンプトのバージョン番号
    - `{name}`: プロンプトの名前部分
    - `{R}`: 実行回数（1 または 2）
    ```
    (186-199 行目を置換)

- **Phase 4 エラーメッセージ改善** (I-4):
  - 現在: 233-236 行目「一部失敗」のエラーメッセージが不明確
  - 改善: 以下に差し替え:
    ```markdown
    - **一部失敗**: `AskUserQuestion` で確認する
      - ベースラインが成功している場合のみ、以下の選択肢を提示:
        - **再試行**: 失敗した採点タスクのみ再実行する（1回のみ）
        - **失敗プロンプトを除外して続行**: 成功したプロンプトのみで Phase 5 へ進む
        - **中断**: エラー内容を出力してスキルを終了する
      - ベースラインが失敗している場合:
        - エラーメッセージに「ベースラインの採点に失敗したため、比較ができません。中断します」を明記し、スキルを終了する
    ```

- **Phase 6 Step 2 の並列実行順序明確化** (C-1, I-2):
  - 現在: 281-323 行目で「Step 2」として A, B, C の処理が記載されているが、実行順序が不明確
  - 改善: 281-323 行目を以下に差し替え:
    ```markdown
    #### ステップ2: ナレッジ更新・スキル知見フィードバック・次アクション選択

    **実行順序**:
    1. A) ナレッジ更新サブエージェントを実行し、完了を待つ
    2. B) スキル知見フィードバックサブエージェント と C) 次アクション選択（親で実行）を並列実行する
    3. B) の完了を待ち、選択結果に応じて分岐する

    **A) ナレッジ更新サブエージェント**

    `Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

    `.claude/skills/agent_bench_new/templates/phase6a-knowledge-update.md` を Read で読み込み、その内容に従って処理を実行してください。
    パス変数:
    - `{knowledge_path}`: `.agent_bench/{agent_name}/knowledge.md` の絶対パス
    - `{report_save_path}`: `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md`
    - `{recommended_name}`, `{judgment_reason}`: Phase 5 のサブエージェント返答の recommended と reason

    サブエージェント失敗時: エラー内容を出力してスキルを終了する

    **A) の完了を待ってから、以下の2つを並列実行する:**

    **B) スキル知見フィードバックサブエージェント**

    `Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

    `.claude/skills/agent_bench_new/templates/phase6b-proven-techniques-update.md` を Read で読み込み、その内容に従って処理を実行してください。
    パス変数:
    - `{proven_techniques_path}`: `.claude/skills/agent_bench_new/proven-techniques.md` の絶対パス
    - `{knowledge_path}`: `.agent_bench/{agent_name}/knowledge.md` の絶対パス
    - `{report_save_path}`: `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md`
    - `{agent_name}`: Phase 0 で決定した値

    サブエージェント失敗時: 警告を出力して続行（proven-techniques.md 更新は任意のため）

    **C) 次アクション選択（親で実行、B と並列）**

    `AskUserQuestion` でユーザーに確認する:
    - 選択肢:
      1. **次ラウンドへ** — 続けて最適化を実行する
      2. **終了** — 最適化を終了する
    - 収束判定が「収束の可能性あり」の場合はその旨を付記する
    - 累計ラウンド数が3以上の場合は「目標ラウンド数に達しました」を付記する

    **B) の完了を待ってから分岐:**
    - 「次ラウンド」の場合: Phase 1B に戻る
    - 「終了」の場合: 以下の最終サマリを出力してスキル完了

    （最終サマリのフォーマットは現在の 325-340 行目をそのまま維持）
    ```

### 2. templates/phase0-perspective-generation.md（修正）
**対応フィードバック**: I-5 [stability]: 出力フォーマット決定性: サブエージェント返答行数が未定義

**変更内容**:
- **返答フォーマット明示** (I-5):
  - 現在: 62 行目「検証成功 → 以下の1行を返答する:」のみで、返答行数が不明確
  - 改善: 59-63 行目を以下に差し替え:
    ```markdown
    - 検証成功 → 以下の**1行のみ**を返答する（他のテキストは含めない）:
      ```
      perspective 自動生成完了: {perspective_save_path}
      ```
    ```

### 3. templates/perspective/critic-effectiveness.md（修正）
**対応フィードバック**: C-2 [stability]: 参照整合性: 未定義変数の使用

**変更内容**:
- **未定義変数削除** (C-2):
  - 現在: 22-23 行目に `{existing_perspectives_summary}` の参照がある
  - 改善: 21-29 行目を以下に差し替え:
    ```markdown
    ### ステップ3: 境界明確性の検証

    - 評価スコープの5項目について、既存の perspective ファイルとのスコープ重複がないか検討する
      - 重複がある場合、具体的にどの項目同士が重複する可能性があるか特定
    - スコープ外の相互参照を確認する
      - 参照先の観点が実際にその項目をスコープに含んでいるか検証
    - ボーナス/ペナルティの判定指針が境界ケースをカバーしているか評価する
    ```

### 4. templates/perspective/critic-completeness.md（修正）
**対応フィードバック**: I-6 [stability]: 出力フォーマット決定性: テンプレート内の返答フォーマットが曖昧

**変更内容**:
- **テーブル行数制限明示** (I-6):
  - 現在: 94 行目「| Essential Design Element | Detectable if Missing | Evidence | Improvement Proposal |」のみで行数制限がない
  - 改善: 93-96 行目を以下に差し替え:
    ```markdown
    **Missing Element Detection Evaluation** - Table with exactly 5-8 rows (no more, no less):
    | Essential Design Element | Detectable if Missing | Evidence | Improvement Proposal |
    |-------------------------|----------------------|----------|---------------------|
    (Exactly 5-8 rows must be provided)
    ```

### 5. templates/phase1b-variant-generation.md（修正）
**対応フィードバック**: I-7 [stability]: 条件分岐の完全性: 暗黙的条件の存在

**変更内容**:
- **else 節追加** (I-7):
  - 現在: 8-10 行目「audit ファイルを読み込んだ場合: 検出された改善提案のリスト...を生成し」で、読み込まなかった場合の処理が不明確
  - 改善: 8-10 行目を以下に差し替え:
    ```markdown
    - {audit_dim1_path} が指定されている場合: Read で読み込む（agent_audit の基準有効性分析結果 — 改善推奨をバリアント生成の参考にする）
    - {audit_dim2_path} が指定されている場合: Read で読み込む（agent_audit のスコープ整合性分析結果 — スコープ改善をバリアント生成の参考にする）
    - audit ファイルを読み込んだ場合: 検出された改善提案のリスト（各項目: 次元、カテゴリ、指摘内容）を生成し、ファイル末尾に `## Audit 統合候補` セクションとして記載する
    - audit ファイルを読み込まなかった場合: `## Audit 統合候補` セクションは省略する
    ```

### 6. templates/phase3-evaluation.md（新規作成）
**対応フィードバック**: I-1 [architecture, ux, efficiency]: Phase 3 指示の埋め込み

**変更内容**:
- **新規テンプレートファイル作成** (I-1):
  - 目的: Phase 3 の並列評価実行指示を外部化し、SKILL.md のコンテキスト負荷を軽減
  - 内容:
    ```markdown
    以下の手順でタスクを実行してください:

    ## パス変数
    - `{prompt_path}`: 評価対象プロンプトの絶対パス
    - `{test_doc_path}`: `.agent_bench/{agent_name}/test-document-round-{NNN}.md`
    - `{result_path}`: `.agent_bench/{agent_name}/results/v{NNN}-{name}-run{R}.md`
    - `{NNN}`: プロンプトのバージョン番号
    - `{name}`: プロンプトの名前部分
    - `{R}`: 実行回数（1 または 2）

    ## 手順

    1. Read で {prompt_path} を読み込み、その内容に従ってタスクを実行してください
    2. Read で {test_doc_path} を読み込み、処理対象としてください
    3. 処理結果を Write で {result_path} に保存してください
    4. 最後に「保存完了: {result_path}」とだけ返答してください

    進捗メッセージ: タスク開始時に「評価実行中: {name} (Run {R})」と出力してください
    ```

## 新規作成ファイル
| ファイル | 目的 | 対応フィードバック |
|---------|------|------------------|
| templates/phase3-evaluation.md | Phase 3 の並列評価実行指示を外部化し、SKILL.md の行数を削減 | I-1 |

## 削除推奨ファイル
（なし）

## 実装順序
1. **templates/phase3-evaluation.md（新規作成）** — SKILL.md の Phase 3 改善で参照するため先に作成
2. **templates/perspective/critic-effectiveness.md（修正）** — 単独の変更で他ファイルに依存しない
3. **templates/perspective/critic-completeness.md（修正）** — 単独の変更で他ファイルに依存しない
4. **templates/phase0-perspective-generation.md（修正）** — 単独の変更で他ファイルに依存しない
5. **templates/phase1b-variant-generation.md（修正）** — 単独の変更で他ファイルに依存しない
6. **SKILL.md（修正）** — 全テンプレートの変更完了後に参照先を更新

依存関係の検出方法:
- 新規作成ファイル（templates/phase3-evaluation.md）を SKILL.md が参照するため、新規作成を先に実施
- 他の変更は全て独立しており、並行実施可能

## 注意事項
- SKILL.md の Phase 0/1A/1B/2/3/4/6 の変更は既存のワークフローロジックを壊さないこと
- templates/phase3-evaluation.md の新規作成に伴い、SKILL.md の Phase 3 セクション（186-199 行目）で正しく参照すること
- Phase 6 Step 2 の並列実行順序変更により、サブエージェント起動タイミングが変わる点に注意（A完了 → B/C並列 → B完了待機）
- SKILL.md の Phase 0 パス変数追加により、`phase0-perspective-resolution.md` で `{existing_perspectives_summary}` を使用可能になるが、今回の改善計画では `critic-effectiveness.md` から該当変数を削除する方針とする
