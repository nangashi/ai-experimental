# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | 外部スキルへのパス参照修正（agent_bench → agent_bench_new） | C-1 |
| 2 | SKILL.md | 修正 | Phase 1B の NNN 変数定義追加 | C-2 |
| 3 | SKILL.md | 修正 | 「構造最適化」の定義明確化と成功基準追加 | C-3 |
| 4 | SKILL.md | 修正 | Phase 1B audit パス変数の定義明確化 | C-4 |
| 5 | SKILL.md | 修正 | Phase 3/4 再試行失敗時の動作明示 | C-5 |
| 6 | SKILL.md | 修正 | Phase 3 評価の冪等性改善（既存ファイル削除） | I-2 |
| 7 | SKILL.md | 修正 | Phase 1B audit ファイル読み込みを最新ラウンドのみに制限 | I-3 |
| 8 | SKILL.md | 修正 | Phase 1B audit findings 存在確認追加 | I-4 |
| 9 | SKILL.md | 修正 | Phase 6 Step 2 並列実行の依存関係明確化 | I-5 |
| 10 | SKILL.md | 修正 | Phase 3 収束後の1回実行自動切り替え追加 | I-6 |
| 11 | SKILL.md | 修正 | perspective 再生成時の確認追加 | I-7 |
| 12 | SKILL.md | 修正 | Phase 0 reference perspective 読み込み効率化 | I-8 |
| 13 | SKILL.md | 修正 | Phase 0 knowledge.md 内容検証追加 | I-9 |
| 14 | templates/phase1b-variant-generation.md | 修正 | audit パス変数を SKILL.md の定義に統一 | C-4 |
| 15 | templates/phase1b-variant-generation.md | 修正 | audit findings 不在時のハンドリング指示追加 | I-4 |
| 16 | templates/phase4-scoring.md | 修正 | perspective.md 参照の目的明記または削除 | I-1 |

## 新規作成ファイル
| ファイル | 目的 | 対応フィードバック |
|---------|------|------------------|
| templates/phase3-evaluation.md | Phase 3 インライン指示のテンプレート外部化 | C-6 |
| templates/phase6a-deploy.md | Phase 6 Step 1 インライン指示のテンプレート外部化 | C-7 |

## 削除推奨ファイル
なし

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**: C-1, C-2, C-3, C-4, C-5, C-6, C-7, I-1, I-2, I-3, I-4, I-5, I-6, I-7, I-8, I-9

**変更内容**:

- **C-1 外部スキルパス参照の修正**:
  - L54: `.claude/skills/agent_bench/perspectives/` → `.claude/skills/agent_bench_new/perspectives/`
  - L74: `.claude/skills/agent_bench/perspectives/design/*.md` → `.claude/skills/agent_bench_new/perspectives/design/*.md`
  - L81-96: `.claude/skills/agent_bench/templates/perspective/` → `.claude/skills/agent_bench_new/templates/perspective/`（4箇所）
  - L123: `.claude/skills/agent_bench/templates/knowledge-init-template.md` → `.claude/skills/agent_bench_new/templates/knowledge-init-template.md`
  - L146: `.claude/skills/agent_bench/templates/phase1a-variant-generation.md` → `.claude/skills/agent_bench_new/templates/phase1a-variant-generation.md`
  - L165: `.claude/skills/agent_bench/templates/phase1b-variant-generation.md` → `.claude/skills/agent_bench_new/templates/phase1b-variant-generation.md`
  - L182: `.claude/skills/agent_bench/templates/phase2-test-document.md` → `.claude/skills/agent_bench_new/templates/phase2-test-document.md`
  - L186: `.claude/skills/agent_bench/test-document-guide.md` → `.claude/skills/agent_bench_new/test-document-guide.md`
  - L246: `.claude/skills/agent_bench/templates/phase4-scoring.md` → `.claude/skills/agent_bench_new/templates/phase4-scoring.md`
  - L251: `.claude/skills/agent_bench/scoring-rubric.md` → `.claude/skills/agent_bench_new/scoring-rubric.md`
  - L270: `.claude/skills/agent_bench/templates/phase5-analysis-report.md` → `.claude/skills/agent_bench_new/templates/phase5-analysis-report.md`
  - L274: `.claude/skills/agent_bench/scoring-rubric.md` → `.claude/skills/agent_bench_new/scoring-rubric.md`
  - L322: `.claude/skills/agent_bench/templates/phase6a-knowledge-update.md` → `.claude/skills/agent_bench_new/templates/phase6a-knowledge-update.md`
  - L334: `.claude/skills/agent_bench/templates/phase6b-proven-techniques-update.md` → `.claude/skills/agent_bench_new/templates/phase6b-proven-techniques-update.md`
  - L338: `.claude/skills/agent_bench/proven-techniques.md` → `.claude/skills/agent_bench_new/proven-techniques.md`
  - L151: `.claude/skills/agent_bench/approach-catalog.md` → `.claude/skills/agent_bench_new/approach-catalog.md`
  - L151: `.claude/skills/agent_bench/proven-techniques.md` → `.claude/skills/agent_bench_new/proven-techniques.md`
  - L171: `.claude/skills/agent_bench/approach-catalog.md` → `.claude/skills/agent_bench_new/approach-catalog.md`
  - L172: `.claude/skills/agent_bench/proven-techniques.md` → `.claude/skills/agent_bench_new/proven-techniques.md`

- **C-2 Phase 1B の NNN 変数定義追加**:
  - L163（Phase 1B セクション）に以下を追加:
    ```
    #### Phase 1B: 継続 — 知見ベースのバリアント生成

    プロンプト保存パスの {NNN} は累計ラウンド数 + 1 とする（knowledge.md から累計ラウンド数を読み取る）。
    ```

- **C-3 「構造最適化」の定義明確化**:
  - L6-7を修正:
    ```markdown
    エージェント定義ファイル（mdファイル）を新規作成または既存改善し、テストに対する性能を反復的に比較評価して最適化します。各ラウンドで得られた知見を `knowledge.md` に蓄積し、反復的に改善します。

    **構造最適化の完了基準**:
    - 収束判定基準を満たす（scoring-rubric.md の収束判定参照）
    - またはユーザー指定ラウンド数に達する
    - 推奨最低ラウンド数: 3ラウンド（全カテゴリで最低1回の基本バリエーションテスト）
    ```

- **C-4 Phase 1B audit パス変数の明確化**:
  - L174を修正:
    ```markdown
    - Glob で `.agent_audit/{agent_name}/run-*/audit-*.md` を検索し（`audit-approved.md` は除外）、最新ラウンドのファイルのみ抽出する
    - 見つかった場合、以下のパス変数を定義してテンプレートに渡す:
      - `{audit_dim1_path}`: `audit-ce-*.md` の最新ファイル（基準有効性分析結果）
      - `{audit_dim2_path}`: `audit-sa-*.md` の最新ファイル（スコープ整合性分析結果）
    - 見つからない場合は空文字列として渡す
    ```

- **C-5 Phase 3/4 再試行失敗時の動作明示**:
  - L233-236を修正:
    ```markdown
    - **いずれかのプロンプトで成功結果が0回**: `AskUserQuestion` で確認する
      - **再試行**: 失敗したタスクのみ再実行する（1回のみ。再試行失敗時は再度確認を求める）
      - **該当プロンプトを除外して続行**: 成功結果があるプロンプトのみで Phase 4 へ進む
      - **中断**: エラー内容を出力してスキルを終了する
    ```
  - L262-264を同様に修正

- **C-6 Phase 3 インライン指示のテンプレート外部化**:
  - L213-221を修正:
    ```markdown
    各サブエージェントへの指示:

    `.claude/skills/agent_bench_new/templates/phase3-evaluation.md` を Read で読み込み、その内容に従って処理を実行してください。
    パス変数:
    - `{prompt_path}`: 評価対象プロンプトの絶対パス
    - `{test_doc_path}`: `.agent_bench/{agent_name}/test-document-round-{NNN}.md`
    - `{result_path}`: `.agent_bench/{agent_name}/results/v{NNN}-{name}-run{R}.md`
    ```

- **C-7 Phase 6 Step 1 デプロイ指示のテンプレート外部化**:
  - L307-314を修正:
    ```markdown
    - **ベースライン以外を選択した場合**: `Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "haiku"`）:

      `.claude/skills/agent_bench_new/templates/phase6a-deploy.md` を Read で読み込み、その内容に従って処理を実行してください。
      パス変数:
      - `{selected_prompt_path}`: ユーザーが選択したプロンプトの絶対パス
      - `{agent_path}`: エージェント定義ファイルの絶対パス
    ```

- **I-1 perspective 問題バンクと採点の依存関係明確化**:
  - L254にコメント追加:
    ```markdown
    - `{perspective_path}`: `.agent_bench/{agent_name}/perspective.md` の絶対パス（ボーナス/ペナルティ判定基準を参照）
    ```

- **I-2 Phase 3 再実行時のファイル削除**:
  - L199-205を修正:
    ```markdown
    ### Phase 3: 並列評価実行

    Phase 3 開始前に、該当ラウンドの既存 results/ ファイルを削除する（Bash ツールで `rm -f .agent_bench/{agent_name}/results/v{NNN}-*.md` を実行）。

    Phase 3 開始時に以下をテキスト出力する:

    ```
    ## Phase 3: 並列評価実行
    - 評価タスク数: {N}（{プロンプト数} × 2回）
    - 実行プロンプト: {プロンプト名リスト}
    ```
    ```

- **I-3 Phase 1B audit ファイル読み込みの効率化**:
  - C-4 の変更で対応済み（最新ラウンドのみに制限）

- **I-4 Phase 1B audit findings 存在確認**:
  - C-4 の変更で対応済み（空文字列として渡す処理を追加）

- **I-5 Phase 6 Step 2 並列実行の依存関係明確化**:
  - L316-354を修正:
    ```markdown
    #### ステップ2: ナレッジ更新・スキル知見フィードバック・次アクション選択

    **A) ナレッジ更新（最初に実行）**

    `Task` ツールで以下を実行し、完了を待つ（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

    `.claude/skills/agent_bench_new/templates/phase6a-knowledge-update.md` を Read で読み込み、その内容に従って処理を実行してください。
    パス変数:
    - `{knowledge_path}`: `.agent_bench/{agent_name}/knowledge.md` の絶対パス
    - `{report_save_path}`: `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md`
    - `{recommended_name}`, `{judgment_reason}`: Phase 5 のサブエージェント返答の recommended と reason

    **B) スキル知見フィードバック（A完了後に実行）**

    `Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

    `.claude/skills/agent_bench_new/templates/phase6b-proven-techniques-update.md` を Read で読み込み、その内容に従って処理を実行してください。
    パス変数:
    - `{proven_techniques_path}`: `.claude/skills/agent_bench_new/proven-techniques.md` の絶対パス
    - `{knowledge_path}`: `.agent_bench/{agent_name}/knowledge.md` の絶対パス
    - `{report_save_path}`: `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md`
    - `{agent_name}`: Phase 0 で決定した値

    **C) 次アクション選択（B と並列実行可能）**

    `AskUserQuestion` でユーザーに確認する:
    - 選択肢:
      1. **次ラウンドへ** — 続けて最適化を実行する
      2. **終了** — 最適化を終了する
    - 収束判定が「収束の可能性あり」の場合はその旨を付記する
    - 累計ラウンド数が3以上の場合は「推奨最低ラウンド数に達しました」を付記する

    B) とC) の完了を待ってから:
    - 「次ラウンド」の場合: Phase 1B に戻る
    - 「終了」の場合: 以下の最終サマリを出力してスキル完了
    ```

- **I-6 Phase 3 収束後の1回実行自動切り替え**:
  - L207に追加:
    ```markdown
    各プロンプトを実行する回数を決定する:
    - 収束判定が未達成の場合: 各プロンプトを2回ずつ実行
    - 収束判定が達成済みの場合（前回ラウンドの Phase 5 で判定）: 各プロンプトを1回のみ実行（SD計算は前回ラウンドの値を参照）

    各プロンプトを `Task` ツールで並列実行する（全て同一メッセージ内で起動）:
    ```

- **I-7 perspective 再生成時の確認追加**:
  - L104-107を修正:
    ```markdown
    **Step 5: フィードバック統合・再生成**
    - 4件の批評から「重大な問題」「改善提案」を分類する
    - 重大な問題または改善提案がある場合:
      - 批評結果を要約し、`AskUserQuestion` で再生成するか確認する
      - ユーザーが承認した場合、フィードバックを `{user_requirements}` に追記し、Step 3 と同じパターンで perspective を再生成する（1回のみ）
    - 改善不要の場合: 現行 perspective を維持する
    ```

- **I-8 Phase 0 reference perspective 読み込みの効率化**:
  - L74-76を修正:
    ```markdown
    **Step 2: 既存 perspective の参照データ収集**
    - `.claude/skills/agent_bench_new/perspectives/design/security.md` を固定パスとして使用する（構造とフォーマットの参考用）
    - ファイルが見つからない場合は `{reference_perspective_path}` を空とする
    ```

- **I-9 Phase 0 knowledge.md 内容検証追加**:
  - L116-118を修正:
    ```markdown
    6. `.agent_bench/{agent_name}/knowledge.md` を Read で読み込む
       - **読み込み成功**: 必須セクション（「## バリエーションステータス」「## ラウンド別スコア推移」）の存在を確認する
         - 検証成功 → Phase 1B へ
         - 検証失敗 → エラー出力し、knowledge.md を再初期化して Phase 1A へ
       - **読み込み失敗**（ファイル不在）→ knowledge.md を初期化して Phase 1A へ
    ```

### 2. templates/phase1b-variant-generation.md（修正）
**対応フィードバック**: C-4, I-4

**変更内容**:

- **L8-9 audit パス変数を個別変数に統一**:
  - 現在の記述: `{audit_dim1_path}`, `{audit_dim2_path}` が指定されている場合
  - 変更後: SKILL.md の定義（C-4）に合わせて、空文字列チェックを追加
    ```markdown
    - {audit_dim1_path} が空でない場合: Read で読み込む（agent_audit の基準有効性分析結果 — 改善推奨をバリアント生成の参考にする）
    - {audit_dim2_path} が空でない場合: Read で読み込む（agent_audit のスコープ整合性分析結果 — スコープ改善をバリアント生成の参考にする）
    - いずれも空の場合: audit 結果を参照せず、knowledge.md のみでバリアント生成する
    ```

### 3. templates/phase4-scoring.md（修正）
**対応フィードバック**: I-1

**変更内容**:
- perspective.md 参照の目的を明記するコメント追加（または参照が不要であれば削除）
- 実際のテンプレート内容確認が必要（現在未読）

## 新規作成ファイル

### 1. templates/phase3-evaluation.md（新規作成）
**対応フィードバック**: C-6

**作成内容**:
```markdown
以下の手順でタスクを実行してください:

1. Read で {prompt_path} を読み込み、その内容に従ってタスクを実行してください
2. Read で {test_doc_path} を読み込み、処理対象としてください
3. 処理結果を Write で {result_path} に保存してください
4. 最後に「保存完了: {result_path}」とだけ返答してください

パス変数:
- `{prompt_path}`: 評価対象プロンプトの絶対パス
- `{test_doc_path}`: テスト対象文書の絶対パス
- `{result_path}`: 結果保存先の絶対パス
```

### 2. templates/phase6a-deploy.md（新規作成）
**対応フィードバック**: C-7

**作成内容**:
```markdown
以下の手順でプロンプトをデプロイしてください:

1. Read で {selected_prompt_path} を読み込む
2. ファイル先頭の <!-- Benchmark Metadata ... --> ブロックを除去する
3. {agent_path} に Write で上書き保存する
4. 「デプロイ完了: {agent_path}」とだけ返答する

パス変数:
- `{selected_prompt_path}`: ユーザーが選択したプロンプトの絶対パス
- `{agent_path}`: エージェント定義ファイルの絶対パス
```

## 実装順序

1. **templates/phase3-evaluation.md 新規作成** — SKILL.md の Phase 3 で参照するため先に作成
2. **templates/phase6a-deploy.md 新規作成** — SKILL.md の Phase 6 で参照するため先に作成
3. **SKILL.md 修正** — 新規テンプレートファイルへの参照を含む全修正を適用
4. **templates/phase1b-variant-generation.md 修正** — SKILL.md の audit パス変数定義（C-4）と整合させる
5. **templates/phase4-scoring.md 確認と修正** — perspective.md 参照の目的明記（実際の内容確認後に実施）

依存関係の検出方法:
- 新規テンプレートファイル作成（1, 2） → SKILL.md でのテンプレート参照追加（3） → 1, 2が先
- SKILL.md の audit パス変数定義（3） → templates/phase1b-variant-generation.md での参照（4） → 3が先（または同時）

## 注意事項
- 変更によって既存のワークフローが壊れないこと
- テンプレート外部化（phase3-evaluation.md, phase6a-deploy.md）では、SKILL.md の参照箇所も同時に更新すること
- 新規テンプレートのパス変数が SKILL.md で定義されていること
- Phase 0 reference perspective の固定パス（I-8）は、実際のファイル存在を確認してから適用すること
- Phase 3 の収束判定による実行回数制御（I-6）は、knowledge.md または前回ラウンドの report から収束判定状態を読み取る必要がある
- Phase 0 knowledge.md 内容検証（I-9）では、セクション見出しの完全一致確認を行うこと
