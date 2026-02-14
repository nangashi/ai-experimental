# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 6 Step 2C 実行条件の明示化、Phase 0 Step 2 フォールバックパス構成例の追記、Phase 0 Step 2 reference_perspective_path 空時の動作明示、Phase 1A user_requirements 常時渡しの明記、Phase 0 Step 5 統合処理の親での実施化、Phase 0 Step 5 perspective.md Read 確認の冪等性保証、Phase 1B agent_audit 参照の曖昧性解消 | C-1, C-3, C-4, I-1, I-5, I-7, I-6 |
| 2 | templates/phase5-analysis-report.md | 修正 | スコアサマリの具体的参照フィールド明記 | C-5 |
| 3 | templates/phase3-evaluation.md | 新規作成 | Phase 3 評価実行サブエージェント指示の外部化 | I-2 |
| 4 | templates/phase6a-deploy.md | 新規作成 | Phase 6 Step 1 デプロイサブエージェント指示の外部化 | I-3 |
| 5 | templates/phase1b-variant-generation.md | 修正 | approach-catalog.md 読込み条件の明確化、agent_audit 参照の具体的処理方法明記 | I-4, I-6 |
| 6 | templates/phase2-test-document.md | 修正 | knowledge.md 参照目的の明記 | I-8 |
| 7 | templates/phase6b-proven-techniques-update.md | 修正 | 類似度判定基準の本文反映 | I-9 |
| 8 | templates/perspective/generate-perspective.md | 修正 | reference_perspective_path 空時の動作明記 | C-4 |
| 9 | templates/perspective/critic-completeness.md | 修正 | 統合処理を本テンプレート内で実施するよう変更 | I-5 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**: C-1, C-3, C-4, I-1, I-5, I-7, I-6

**変更内容**:
- **行368-369 (C-1)**: `A) と B) の両方が完了したことを確認した上で` → `A) と B) のサブエージェントタスクが正常に完了したことを Task ツールの返答で確認し、その後`
- **行66 (C-3)**: フォールバックパス構成の具体例を追記
  ```markdown
  - 一致した場合: `.claude/skills/agent_bench_new/perspectives/{target}/{key}.md` を Read で確認する
    （例: `security-design-reviewer` → `.claude/skills/agent_bench_new/perspectives/design/security.md`、`best-practices-code-reviewer` → `.claude/skills/agent_bench_new/perspectives/code/best-practices.md`）
  ```
- **行88 (C-4)**: `見つからない場合は {reference_perspective_path} を空とする` → `見つからない場合は {reference_perspective_path} を空文字列とする（Step 3 で reference_perspective_path が空の場合は Read をスキップする）`
- **行175-176 (I-1)**: 条件分岐の記述を削除し、常に渡す旨を明記
  ```markdown
  - エージェント定義が新規作成の場合:
    - `{user_requirements}`: Phase 0 で収集した要件テキスト
  ```
  ↓
  ```markdown
  - `{user_requirements}`: Phase 0 で収集した要件テキスト（エージェント定義が既存の場合は空文字列）
  ```
- **行117-122 (I-5)**: 4並列批評→親で統合の記述を変更
  ```markdown
  **Step 5: フィードバック統合・再生成**
  - 4件の批評結果を Read で読み込み（`.agent_bench/{agent_name}/perspective-critique-{名前}.md`）、各ファイルから「重大な問題」「改善提案」のセクションを抽出して統合する。重複する指摘は最も具体的な記述を採用する
  ```
  ↓
  ```markdown
  **Step 5: フィードバック統合・再生成**
  - critic-completeness サブエージェントが統合済みフィードバックを返答する（`.agent_bench/{agent_name}/perspective-critique-completeness.md` に保存済み）
  - 統合済みフィードバックに重大な問題または改善提案がある場合: フィードバックを `{user_requirements}` に追記し、Step 3 と同じパターンで perspective を再生成する（1回のみ）
  ```
- **行72 (I-7)**: `Read で .agent_bench/{agent_name}/perspective.md の存在確認を行う。ファイルが存在しない場合のみ` の後に補足を追加
  ```markdown
  Read で `.agent_bench/{agent_name}/perspective.md` の存在確認を行う。ファイルが既に存在する場合は再生成をスキップする（冪等性保証）。存在しない場合のみ、perspective-source.md から「## 問題バンク」セクション以降を除いた内容を Write で保存する
  ```
- **行194 (I-6)**: `{audit_findings_paths}` の説明を詳細化
  ```markdown
  - `{audit_findings_paths}`: Glob で `.agent_audit/{agent_name}/audit-*.md` を検索する（`audit-approved.md` は除外）
    - 見つかった場合: 全ファイルのパスをカンマ区切りで渡す
  ```
  ↓
  ```markdown
  - `{audit_findings_paths}`: Glob で `.agent_audit/{agent_name}/audit-*.md` を検索する（`audit-approved.md` は除外）
    - 見つかった場合: 全ファイルのパスをカンマ区切りで渡す（バリアント生成時に基準有効性・スコープ整合性の改善推奨を考慮する）
    - 見つからない場合: 空文字列を渡す
  ```
- **行235-242 (I-2)**: Phase 3 の直接指示を削除し、テンプレート参照に変更
  ```markdown
  各サブエージェントへの指示:

  ```
  以下の手順でタスクを実行してください:

  1. Read で {prompt_path} を読み込み、その内容に従ってタスクを実行してください
  2. Read で {test_doc_path} を読み込み、処理対象としてください
  3. 処理結果を Write で {result_path} に保存してください
  4. 最後に「保存完了: {result_path}」とだけ返答してください
  ```
  ```
  ↓
  ```markdown
  `.claude/skills/agent_bench_new/templates/phase3-evaluation.md` を Read で読み込み、その内容に従って処理を実行してください。
  パス変数:
  - `{prompt_path}`: 評価対象プロンプトの絶対パス
  - `{test_doc_path}`: `.agent_bench/{agent_name}/test-document-round-{NNN}.md` の絶対パス
  - `{result_path}`: `.agent_bench/{agent_name}/results/v{NNN}-{name}-run{1,2}.md` の絶対パス
  ```
- **行328-335 (I-3)**: Phase 6 Step 1 の直接指示を削除し、テンプレート参照に変更
  ```markdown
  - **ベースライン以外を選択した場合**: `Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "haiku"`）:
    ```
    以下の手順でプロンプトをデプロイしてください:
    1. Read で {selected_prompt_path} を読み込む
    2. ファイル先頭の <!-- Benchmark Metadata ... --> ブロックを除去する
    3. {agent_path} に Write で上書き保存する
    4. 「デプロイ完了: {agent_path}」とだけ返答する
    ```
  ```
  ↓
  ```markdown
  - **ベースライン以外を選択した場合**: `Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "haiku"`）:
    `.claude/skills/agent_bench_new/templates/phase6a-deploy.md` を Read で読み込み、その内容に従って処理を実行してください。
    パス変数:
    - `{selected_prompt_path}`: 選択されたプロンプトファイルの絶対パス
    - `{agent_path}`: エージェント定義ファイルの絶対パス
  ```

### 2. templates/phase5-analysis-report.md（修正）
**対応フィードバック**: C-5

**変更内容**:
- **行9**: `注記: 各採点結果ファイルから「スコアサマリ」セクションのみを抽出し、比較レポートを生成する。問題別の詳細検出結果は参照しない` → `注記: 各採点結果ファイルから「スコアサマリ」セクションのみを抽出し、比較レポートを生成する。具体的には Mean, SD, Run1スコア（○/△/×件数とボーナス/ペナルティ）、Run2スコアのみを使用する。問題別の詳細検出結果は参照しない`

### 3. templates/phase3-evaluation.md（新規作成）
**対応フィードバック**: I-2

**ファイル内容**:
```markdown
以下の手順でタスクを実行してください:

1. Read で {prompt_path} を読み込み、その内容に従ってタスクを実行してください
2. Read で {test_doc_path} を読み込み、処理対象としてください
3. 処理結果を Write で {result_path} に保存してください
4. 最後に「保存完了: {result_path}」とだけ返答してください
```

### 4. templates/phase6a-deploy.md（新規作成）
**対応フィードバック**: I-3

**ファイル内容**:
```markdown
以下の手順でプロンプトをデプロイしてください:

1. Read で {selected_prompt_path} を読み込む
2. ファイル先頭の `<!-- Benchmark Metadata ... -->` ブロックを除去する
3. {agent_path} に Write で上書き保存する
4. 「デプロイ完了: {agent_path}」とだけ返答する
```

### 5. templates/phase1b-variant-generation.md（修正）
**対応フィードバック**: I-4, I-6

**変更内容**:
- **行8-12 (I-6)**: agent_audit 参照の具体的処理方法を明記
  ```markdown
  - {audit_findings_paths} が空でない場合:
    - カンマ区切りでパスを分割する
    - 各パスについて Read で読み込む
    - 読み込んだ内容をバリアント生成時の参考にする（基準有効性・スコープ整合性の改善推奨を考慮）
  ```
  ↓
  ```markdown
  - {audit_findings_paths} が空でない場合:
    - カンマ区切りでパスを分割する
    - 各パスについて Read で読み込む
    - 基準有効性の改善推奨: 評価スコープの曖昧性を排除する変更、例示追加による実行可能性向上を考慮
    - スコープ整合性の改善推奨: スコープ定義の明確化、スコープ外の明示化を考慮
  ```
- **行17 (I-4)**: approach-catalog.md の条件付き読込みを明記
  ```markdown
  - Deep モードの場合、選定したカテゴリの UNTESTED バリエーションの詳細を確認するために {approach_catalog_path} を Read で読み込む。Broad モードではカタログ読み込みは不要（knowledge.md のバリエーションステータステーブルのみで判定可能）
  ```
  ↓
  ```markdown
  - Broad/Deep 判定後に approach-catalog.md の読込みを判断する:
    - Broad モード: knowledge.md のバリエーションステータステーブルのみで判定可能なため、{approach_catalog_path} は読み込まない
    - Deep モード: 選定したカテゴリの UNTESTED バリエーションの詳細を確認するために {approach_catalog_path} を Read で読み込む
  ```

### 6. templates/phase2-test-document.md（修正）
**対応フィードバック**: I-8

**変更内容**:
- **行7**: `- {knowledge_path} （過去の知見 — 「テストセット履歴」セクションのみを参照し、過去と異なるドメインを選択する）` → `- {knowledge_path} （過去の知見 — 「テストセット履歴」セクションのみを参照し、テスト文書の多様性確保のため過去と異なるドメインを選択する）`

### 7. templates/phase6b-proven-techniques-update.md（修正）
**対応フィードバック**: I-9

**変更内容**:
- **行37**: サイズ制限の遵守セクションに類似度判定基準を追記
  ```markdown
  **サイズ制限の遵守**:
  - Section 1: 最大8エントリ。超過時は以下の基準で最も類似する2エントリを判定してマージする: (1) Variation ID のカテゴリ（S/C/N/M）が同一、(2) 効果範囲の記述に共通キーワード（見出し/粒度/例示/形式）が2つ以上含まれる、(3) 出典エージェント数の合計が最も少ない組み合わせを優先
  ```
  ↓
  ```markdown
  **サイズ制限の遵守**:
  - Section 1: 最大8エントリ。超過時は以下の類似度判定基準で最も類似する2エントリをマージする:
    1. Variation ID のカテゴリ（S/C/N/M）が同一
    2. 効果範囲の記述に共通キーワード（見出し/粒度/例示/形式/セクション/構造）が2つ以上含まれる
    3. 上記条件を満たす組み合わせのうち、出典エージェント数の合計が最も少ない組み合わせを優先
  - Section 2: 最大8エントリ。同じ類似度判定基準を適用
  ```

### 8. templates/perspective/generate-perspective.md（修正）
**対応フィードバック**: C-4

**変更内容**:
- **行4**: `{reference_perspective_path} が指定されている場合` の補足を追加
  ```markdown
  - {reference_perspective_path} が指定されている場合: 参照用の観点定義（構造とフォーマットを把握する）
  ```
  ↓
  ```markdown
  - {reference_perspective_path} が空文字列でない場合: Read で参照用の観点定義を読み込む（構造とフォーマットを把握する）
  - {reference_perspective_path} が空文字列の場合: 構造参照なしで生成する（本テンプレートの必須スキーマに従う）
  ```

### 9. templates/perspective/critic-completeness.md（修正）
**対応フィードバック**: I-5

**変更内容**:
- 英語テンプレートの最後に統合処理ステップを追加（親での3ファイル Read を削減）
  ```markdown
  ### Phase 7: Feedback Integration
  - [ ] Read all 4 critique files (`.agent_bench/{agent_name}/perspective-critique-{effectiveness,completeness,clarity,generality}.md`)
  - [ ] Extract "Critical Issues" and "Improvement Suggestions" sections from each file
  - [ ] Consolidate duplicates by preserving the most specific description
  - [ ] Write the integrated feedback to `.agent_bench/{agent_name}/perspective-critique-completeness.md`
  - [ ] Respond with the integrated feedback content only (no need to repeat the entire critique)
  ```

## 新規作成ファイル

| ファイル | 目的 | 対応フィードバック |
|---------|------|------------------|
| templates/phase3-evaluation.md | Phase 3 評価実行サブエージェント指示の外部化（SKILL.md のコンテキスト削減） | I-2 |
| templates/phase6a-deploy.md | Phase 6 Step 1 デプロイサブエージェント指示の外部化（SKILL.md のコンテキスト削減） | I-3 |

## 削除推奨ファイル

該当なし

## 実装順序

1. **templates/phase3-evaluation.md**（新規作成）— Phase 3 評価実行サブエージェント指示の外部化
2. **templates/phase6a-deploy.md**（新規作成）— Phase 6 Step 1 デプロイサブエージェント指示の外部化
3. **templates/perspective/critic-completeness.md**（修正）— 統合処理を本テンプレート内で実施するよう変更（親での3ファイル Read 削減の前提条件）
4. **templates/phase5-analysis-report.md**（修正）— スコアサマリの具体的参照フィールド明記
5. **templates/phase2-test-document.md**（修正）— knowledge.md 参照目的の明記
6. **templates/phase6b-proven-techniques-update.md**（修正）— 類似度判定基準の本文反映
7. **templates/perspective/generate-perspective.md**（修正）— reference_perspective_path 空時の動作明記
8. **templates/phase1b-variant-generation.md**（修正）— approach-catalog.md 読込み条件の明確化、agent_audit 参照の具体的処理方法明記
9. **SKILL.md**（修正）— 全変更の統合（新規テンプレート参照、統合処理変更、各種明示化）

依存関係の検出方法:
- 改善I-5（critic-completeness.md の統合処理追加）の成果物を改善I-5 の SKILL.md 変更が参照するため、critic-completeness.md を先に実施
- 改善I-2/I-3（テンプレート新規作成）の成果物を SKILL.md の変更が参照するため、新規テンプレートを先に実施
- SKILL.md は全変更の集約点となるため最後に実施

## 注意事項

- SKILL.md の Phase 6 Step 2C 実行条件の変更により、サブエージェント完了確認が明示化される
- Phase 0 Step 5 の統合処理を critic-completeness サブエージェント内で実施することにより、親での3ファイル Read が削減される
- Phase 3/Phase 6 Step 1 のテンプレート外部化により、SKILL.md のコンテキスト負荷が軽減される
- templates/phase1b-variant-generation.md の変更により、Broad/Deep 判定後に条件付きで approach-catalog.md を読み込むフローが明確化される
- templates/perspective/generate-perspective.md の変更により、reference_perspective_path が空の場合の動作が明示化される
- templates/phase6b-proven-techniques-update.md の類似度判定基準が本文に反映され、エントリマージ時の判断基準が一貫性を持つ
