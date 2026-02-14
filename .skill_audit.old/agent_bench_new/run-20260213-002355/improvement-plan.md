# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 0 に user_requirements パス変数定義を追加 | C-3: 未定義変数 user_requirements |
| 2 | SKILL.md | 修正 | Phase 1A に user_requirements パス変数を追加 | C-1: Phase 0 → Phase 1A の user_requirements 参照不整合 |
| 3 | SKILL.md | 修正 | Phase 4 に scoring_file_paths 収集プロセスを明示 | C-2: Phase 5 の scoring_file_paths の生成方法が不明 |
| 4 | SKILL.md | 修正 | Phase 3 の phase3-error-handling.md 参照を「親が実行」と明示 | C-4: phase3-error-handling.md の参照整合性 |
| 5 | SKILL.md | 修正 | Phase 0 に perspective.md 検証ステップを追加 | I-2: Phase 0 の perspective 検証ロジックの欠落 |
| 6 | SKILL.md | 修正 | Phase 1B の audit ファイル不在時の処理を明記 | I-4: Phase 1B の audit ファイル不在時の挙動が曖昧 |
| 7 | SKILL.md | 修正 | Phase 6 に効果テーブル抽出ステップを追加 | I-3: 最終サマリで宣言された「効果テーブル上位3件」の取得方法が不明 |
| 8 | SKILL.md | 修正 | Phase 1B の audit 参照をパス変数として明示 | I-1: 外部スキルディレクトリへの直接参照 |
| 9 | templates/phase1a-variant-generation.md | 修正 | user_requirements パス変数の説明を追加 | C-1: Phase 0 → Phase 1A の user_requirements 参照不整合 |
| 10 | templates/phase1b-variant-generation.md | 修正 | audit ファイル空文字列時の処理を明記 | I-4: Phase 1B の audit ファイル不在時の挙動が曖昧 |
| 11 | templates/phase3-error-handling.md | 修正 | 冒頭に「親が実行する手順書」と明記 | C-4: phase3-error-handling.md の参照整合性 |
| 12 | templates/phase0-perspective-validation.md | 新規作成 | perspective.md 必須セクション検証ロジックを外部化 | C-5: SKILL.md 行数超過, I-2: Phase 0 の perspective 検証ロジックの欠落 |
| 13 | templates/phase6-extract-top-techniques.md | 新規作成 | 効果テーブル上位3件抽出ロジックを外部化 | C-5: SKILL.md 行数超過, I-3: 最終サマリで宣言された「効果テーブル上位3件」の取得方法が不明 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）— C-3 対応
**対応フィードバック**: C-3: 未定義変数 user_requirements [stability]

**変更内容**:
- Phase 0 のパースペクティブ解決セクション（54行目付近）: パス変数リストに user_requirements を追加
  ```markdown
  現在:
  - `{agent_name}`: Phase 0 で決定した値
  - `{agent_path}`: エージェント定義ファイルの絶対パス

  改善後:
  - `{agent_name}`: Phase 0 で決定した値
  - `{agent_path}`: エージェント定義ファイルの絶対パス
  - `{user_requirements}`: Phase 0 で収集した要件テキスト（エージェント定義が不足していた場合のみ）
  ```

### 2. SKILL.md（修正）— C-1 対応
**対応フィードバック**: C-1: Phase 0 → Phase 1A の user_requirements 参照不整合 [effectiveness]

**変更内容**:
- Phase 1A のパス変数リスト（127-135行目）: user_requirements の記述を修正
  ```markdown
  現在:
  - エージェント定義が新規作成の場合:
    - `{user_requirements}`: Phase 0 で収集した要件テキスト

  改善後:
  - `{user_requirements}`: Phase 0 で収集した要件テキスト（エージェント定義が不足していた場合のみ。それ以外は空文字列）
  ```

### 3. SKILL.md（修正）— C-2 対応
**対応フィードバック**: C-2: Phase 5 の scoring_file_paths の生成方法が不明 [effectiveness]

**変更内容**:
- Phase 4 末尾（256行目付近）: scoring_file_paths 収集プロセスを追加
  ```markdown
  現在:
    - ベースラインが失敗している場合:
      - エラーメッセージに「ベースラインの採点に失敗したため、比較ができません。中断します」を明記し、スキルを終了する

  改善後:
    - ベースラインが失敗している場合:
      - エラーメッセージに「ベースラインの採点に失敗したため、比較ができません。中断します」を明記し、スキルを終了する

  採点完了後、成功した全プロンプトの採点ファイルパスを収集し、`{scoring_file_paths}` 変数にカンマ区切り文字列として保持する:
  - 例: `.agent_bench/{agent_name}/results/v001-baseline-scoring.md,.agent_bench/{agent_name}/results/v001-variant-minimal-scoring.md`
  ```

### 4. SKILL.md（修正）— C-4 対応
**対応フィードバック**: C-4: phase3-error-handling.md の参照整合性 [stability]

**変更内容**:
- Phase 3 末尾（224行目）: phase3-error-handling.md の実行主体を明示
  ```markdown
  現在:
  全サブエージェント完了後、`templates/phase3-error-handling.md` を Read で読み込み、その内容に従ってエラーハンドリングを実行する

  改善後:
  全サブエージェント完了後、親が `templates/phase3-error-handling.md` を Read で読み込み、その内容に従ってエラーハンドリングを実行する（サブエージェント委譲ではなく、親が直接実行）
  ```

### 5. SKILL.md（修正）— I-2 対応
**対応フィードバック**: I-2: Phase 0 の perspective 検証ロジックの欠落 [architecture]

**変更内容**:
- Phase 0 のパースペクティブ自動生成セクション（84行目付近）の後に検証ステップを追加
  ```markdown
  追加位置: Phase 0 の「共通処理」セクション（85行目）の前

  追加内容:
  #### パースペクティブ検証

  `Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

  `.claude/skills/agent_bench_new/templates/phase0-perspective-validation.md` を Read で読み込み、その内容に従って処理を実行してください。
  パス変数:
  - `{perspective_path}`: `.agent_bench/{agent_name}/perspective.md` の絶対パス

  サブエージェント失敗時: エラーメッセージを出力してスキルを終了する
  ```

### 6. SKILL.md（修正）— I-4 対応
**対応フィードバック**: I-4: Phase 1B の audit ファイル不在時の挙動が曖昧 [effectiveness]

**変更内容**:
- Phase 1B のパス変数リスト（161-163行目）: audit ファイル不在時の処理を明記
  ```markdown
  現在:
  - Glob で `.agent_audit/{agent_name}/audit-*.md` を検索し（`audit-approved.md` は除外）、見つかった全ファイルを以下の変数として渡す:
    - `{audit_dim1_path}`: `audit-ce-*.md` に一致する最初のファイルのパス（見つからない場合は空）
    - `{audit_dim2_path}`: `audit-sa-*.md` に一致する最初のファイルのパス（見つからない場合は空）

  改善後:
  - Glob で `.agent_audit/{agent_name}/audit-*.md` を検索し（`audit-approved.md` は除外）、見つかった全ファイルを以下の変数として渡す:
    - `{audit_dim1_path}`: `audit-ce-*.md` に一致する最初のファイルのパス（見つからない場合は空文字列 `""`）
    - `{audit_dim2_path}`: `audit-sa-*.md` に一致する最初のファイルのパス（見つからない場合は空文字列 `""`）
  - サブエージェントは audit パス変数が空文字列の場合、そのファイルの読み込みをスキップし、`## Audit 統合候補` セクションを省略する
  ```

### 7. SKILL.md（修正）— I-3 対応
**対応フィードバック**: I-3: 最終サマリで宣言された「効果テーブル上位3件」の取得方法が不明 [effectiveness]

**変更内容**:
- Phase 6 ステップ2の A) ナレッジ更新完了後（318行目付近）: 効果テーブル抽出ステップを追加
  ```markdown
  現在:
  サブエージェント失敗時: エラー内容を出力してスキルを終了する

  改善後:
  サブエージェント失敗時: エラー内容を出力してスキルを終了する

  **A) 完了後、効果テーブル上位3件を抽出:**

  `Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

  `.claude/skills/agent_bench_new/templates/phase6-extract-top-techniques.md` を Read で読み込み、その内容に従って処理を実行してください。
  パス変数:
  - `{knowledge_path}`: `.agent_bench/{agent_name}/knowledge.md` の絶対パス

  サブエージェント返答: 効果テーブル上位3件のテクニック名（カンマ区切り）

  返答を `{top_techniques}` 変数として保持し、最終サマリで使用する。
  ```

- Phase 6 最終サマリ（355行目）: top_techniques 変数を参照するよう変更
  ```markdown
  現在:
  - 効果のあったテクニック: {knowledge.md の効果テーブル上位3件}

  改善後:
  - 効果のあったテクニック: {top_techniques}
  ```

### 8. SKILL.md（修正）— I-1 対応
**対応フィードバック**: I-1: 外部スキルディレクトリへの直接参照 [architecture]

**変更内容**:
- Phase 1B のパス変数セクション（161-163行目）: コメントでポリシーを明記
  ```markdown
  現在:
  - Glob で `.agent_audit/{agent_name}/audit-*.md` を検索し（`audit-approved.md` は除外）、見つかった全ファイルを以下の変数として渡す:

  改善後:
  - Glob で `.agent_audit/{agent_name}/audit-*.md` を検索し（`audit-approved.md` は除外）、見つかった全ファイルを以下の変数として渡す:
    - 注: agent_audit の出力ディレクトリに直接アクセスしている。将来的には agent_audit が明示的な出力パスを返す設計に変更すべき
  ```

### 9. templates/phase1a-variant-generation.md（修正）— C-1 対応
**対応フィードバック**: C-1: Phase 0 → Phase 1A の user_requirements 参照不整合 [effectiveness]

**変更内容**:
- 手順1（3-9行目）: user_requirements の扱いを明記
  ```markdown
  現在:
  1. Read で以下のファイルを読み込む:
     - {proven_techniques_path} （実証済みテクニック — ベースライン構築ガイドを含む）
     - {approach_catalog_path} （アプローチカタログ — 共通ルール・推奨構成・改善戦略を含む）
     - {perspective_source_path} （パースペクティブ — 評価スコープと問題バンクを含む）
  2. エージェント定義ファイル {agent_path} を Read で確認する:
     - 存在すれば、その内容をベースライン（比較基準）とする
     - 存在しなければ: {user_requirements} を基に、proven-techniques.md の「ベースライン構築ガイド」に従って生成する。

  改善後:
  1. Read で以下のファイルを読み込む:
     - {proven_techniques_path} （実証済みテクニック — ベースライン構築ガイドを含む）
     - {approach_catalog_path} （アプローチカタログ — 共通ルール・推奨構成・改善戦略を含む）
     - {perspective_source_path} （パースペクティブ — 評価スコープと問題バンクを含む）
  2. エージェント定義ファイル {agent_path} を Read で確認する:
     - 存在すれば、その内容をベースライン（比較基準）とする
     - 存在しなければ: {user_requirements}（Phase 0 から受け取った要件テキスト、または空文字列）を基に、proven-techniques.md の「ベースライン構築ガイド」に従って生成する。user_requirements が空の場合は perspective_source_path の内容を要件として使用する。
  ```

### 10. templates/phase1b-variant-generation.md（修正）— I-4 対応
**対応フィードバック**: I-4: Phase 1B の audit ファイル不在時の挙動が曖昧 [effectiveness]

**変更内容**:
- 手順1（3-10行目）: audit ファイル空文字列時の処理を明記
  ```markdown
  現在:
     - {audit_dim1_path} が指定されている場合: Read で読み込む（agent_audit の基準有効性分析結果 — 改善推奨をバリアント生成の参考にする）
     - {audit_dim2_path} が指定されている場合: Read で読み込む（agent_audit のスコープ整合性分析結果 — スコープ改善をバリアント生成の参考にする）
     - audit ファイルを読み込んだ場合: 検出された改善提案のリスト（各項目: 次元、カテゴリ、指摘内容）を生成し、ファイル末尾に `## Audit 統合候補` セクションとして記載する
     - audit ファイルを読み込まなかった場合: `## Audit 統合候補` セクションは省略する

  改善後:
     - {audit_dim1_path} が空文字列でない場合: Read で読み込む（agent_audit の基準有効性分析結果 — 改善推奨をバリアント生成の参考にする）
     - {audit_dim2_path} が空文字列でない場合: Read で読み込む（agent_audit のスコープ整合性分析結果 — スコープ改善をバリアント生成の参考にする）
     - audit ファイルを1つ以上読み込んだ場合: 検出された改善提案のリスト（各項目: 次元、カテゴリ、指摘内容）を生成し、ファイル末尾に `## Audit 統合候補` セクションとして記載する
     - audit ファイルを1つも読み込まなかった場合（両方とも空文字列）: `## Audit 統合候補` セクションは省略する
  ```

### 11. templates/phase3-error-handling.md（修正）— C-4 対応
**対応フィードバック**: C-4: phase3-error-handling.md の参照整合性 [stability]

**変更内容**:
- ファイル冒頭（1行目）: 実行主体を明示
  ```markdown
  現在:
  # Phase 3 エラーハンドリング詳細

  改善後:
  # Phase 3 エラーハンドリング詳細（親が実行する手順書）

  このファイルはサブエージェントへの委譲用テンプレートではなく、親スキルが直接参照・実行する手順書です。
  ```

### 12. templates/phase0-perspective-validation.md（新規作成）— C-5, I-2 対応
**対応フィードバック**: C-5: SKILL.md 行数超過 [efficiency], I-2: Phase 0 の perspective 検証ロジックの欠落 [architecture]

**変更内容**:
- 新規ファイル作成 → SKILL.md の検証ロジックを外部化して行数削減
  ```markdown
  内容:
  # パースペクティブ検証テンプレート

  以下の手順で perspective.md の必須セクションを検証してください:

  1. Read で `{perspective_path}` を読み込む
  2. 必須セクションの存在を確認する:
     - `# パースペクティブ` または `# Perspective`（見出し）
     - `## 評価観点` または `## Evaluation Criteria`（評価基準を含むセクション）
     - `## 問題バンク` または `## Problem Bank`（テスト生成用の問題セットを含むセクション）
  3. 検証結果に応じて処理する:
     - **全セクション存在**: 次の処理へ進む（返答: `valid`）
     - **不足あり**: 以下のエラーメッセージを出力して終了
       ```
       エラー: perspective.md の必須セクションが不足しています
       - 不足セクション: {セクション名リスト}
       - ファイル: {perspective_path}
       - 対処法: perspective-source.md を修正するか、Phase 0 の perspective 自動生成を再実行してください
       ```

  4. 返答は1行のみ: `valid` または `invalid: {不足セクション名リスト}`
  ```

### 13. templates/phase6-extract-top-techniques.md（新規作成）— C-5, I-3 対応
**対応フィードバック**: C-5: SKILL.md 行数超過 [efficiency], I-3: 最終サマリで宣言された「効果テーブル上位3件」の取得方法が不明 [effectiveness]

**変更内容**:
- 新規ファイル作成 → SKILL.md の抽出ロジックを外部化して行数削減
  ```markdown
  内容:
  # 効果テーブル上位3件抽出テンプレート

  以下の手順で knowledge.md から効果テーブル上位3件を抽出してください:

  1. Read で `{knowledge_path}` を読み込む
  2. `## 効果テーブル` セクションを探す
  3. テーブルから「総合効果スコア」列でソートし、上位3件を抽出する:
     - テーブル形式: `| テクニック | ラウンド数 | 総合効果スコア | ステータス |`
     - ステータスが `EFFECTIVE` の行のみを対象とする
     - 総合効果スコアが同点の場合は、ラウンド数が多い方を優先する
  4. 上位3件のテクニック名をカンマ区切りで返答する（例: `S-1a, C-2b, N-3c`）
     - 3件未満の場合は存在する数のみ返す
     - 0件の場合は `なし` と返す

  5. 返答は1行のみ: カンマ区切りのテクニック名、または `なし`
  ```

## 新規作成ファイル
| ファイル | 目的 | 対応フィードバック |
|---------|------|------------------|
| templates/phase0-perspective-validation.md | perspective.md 必須セクション検証ロジックを外部化 | C-5: SKILL.md 行数超過, I-2: Phase 0 の perspective 検証ロジックの欠落 |
| templates/phase6-extract-top-techniques.md | 効果テーブル上位3件抽出ロジックを外部化 | C-5: SKILL.md 行数超過, I-3: 最終サマリで宣言された「効果テーブル上位3件」の取得方法が不明 |

## 削除推奨ファイル
（なし）

## 実装順序
1. **templates/phase0-perspective-validation.md（新規作成）**
   - 理由: SKILL.md の Phase 0 が参照するため、先に作成する必要がある
2. **templates/phase6-extract-top-techniques.md（新規作成）**
   - 理由: SKILL.md の Phase 6 が参照するため、先に作成する必要がある
3. **templates/phase3-error-handling.md（修正）**
   - 理由: 他ファイルへの依存がなく、単独で修正可能
4. **templates/phase1a-variant-generation.md（修正）**
   - 理由: user_requirements の定義が SKILL.md で明確化された後に修正する
5. **templates/phase1b-variant-generation.md（修正）**
   - 理由: audit パス変数の扱いが SKILL.md で明確化された後に修正する
6. **SKILL.md（修正）— Phase 0 パス変数リスト（C-3 対応）**
   - 理由: 他の Phase への依存がなく、早期に修正可能
7. **SKILL.md（修正）— Phase 0 検証ステップ追加（I-2 対応）**
   - 理由: templates/phase0-perspective-validation.md 作成後に参照を追加
8. **SKILL.md（修正）— Phase 1A パス変数リスト（C-1 対応）**
   - 理由: Phase 0 の user_requirements 定義が完了した後に修正
9. **SKILL.md（修正）— Phase 1B audit 参照（I-4, I-1 対応）**
   - 理由: templates/phase1b-variant-generation.md の修正内容と整合性を保つ
10. **SKILL.md（修正）— Phase 3 エラーハンドリング（C-4 対応）**
    - 理由: templates/phase3-error-handling.md の修正内容と整合性を保つ
11. **SKILL.md（修正）— Phase 4 scoring_file_paths 収集（C-2 対応）**
    - 理由: Phase 5 への依存がなく、単独で修正可能
12. **SKILL.md（修正）— Phase 6 効果テーブル抽出（I-3 対応）**
    - 理由: templates/phase6-extract-top-techniques.md 作成後に参照を追加
13. **SKILL.md（修正）— Phase 6 最終サマリ（I-3 対応続き）**
    - 理由: 効果テーブル抽出ステップ追加後に変数参照を更新

依存関係の検出方法:
- 新規テンプレート作成（1-2）→ SKILL.md でのテンプレート参照追加（7, 12）→ 新規テンプレートが先
- Phase 0 の user_requirements 定義（6）→ Phase 1A での参照追加（8）→ Phase 0 が先
- templates/phase1b-variant-generation.md の audit 扱い明確化（5）→ SKILL.md の audit 参照修正（9）→ テンプレートが先

## 注意事項
- 変更によって既存のワークフローが壊れないこと
- 新規テンプレートのパス変数が SKILL.md で正しく定義されていること
- テンプレート外部化により SKILL.md の行数が削減されること（目標: 350行以下）
- user_requirements の扱いが Phase 0 → Phase 1A で一貫していること
- audit ファイル不在時の処理が Phase 1B とテンプレートで一致していること
