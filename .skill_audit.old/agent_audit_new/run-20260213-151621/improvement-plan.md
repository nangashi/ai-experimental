# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 6 Step 2C を Step 2A/2B 並列起動直後に実行（Step 2B 完了待機削除） | I-1 |
| 2 | SKILL.md | 修正 | Phase 5 → Phase 6 変数マッピングの明示 | I-6 |
| 3 | SKILL.md | 修正 | Phase 3 ベースライン失敗時の除外オプション削除 | I-8 |
| 4 | SKILL.md | 修正 | Phase 0 Step 4 フィードバック統合処理をサブエージェントに委譲 | I-4 |
| 5 | templates/phase4-scoring.md | 修正 | scoring-rubric.md 全文を埋め込み、Read 削除 | I-2 |
| 6 | templates/phase3-evaluation.md | 修正 | プロンプト内容を親から受け取る形式に変更 | I-3 |
| 7 | templates/phase1a-variant-generation.md | 修正 | 「ギャップが大きい次元」判定基準の明示 | I-7 |
| 8 | templates/phase1a-variant-generation.md | 修正 | approach-catalog.md の Read を削除し、必要情報のみ親から受け取る | I-5 |
| 9 | templates/phase1b-variant-generation.md | 修正 | approach-catalog.md の Read を削除し（Deep モード時のみ必要情報を親から受け取る） | I-5 |
| 10 | templates/perspective/consolidate-feedback.md | 新規作成 | 4並列批評結果の統合処理テンプレート | I-4 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**: I-1: Phase 6 Step 2C 逐次待機によるレイテンシ増加

**変更内容**:
- 418-429行: Step 2A/2B 並列起動後、Step 2B の完了を待たずに Step 2C（次アクション選択）を実行
  - 現在: Step 2B 完了待機 → 性能推移表示 → 次アクション選択
  - 改善後: Step 2A/2B 並列起動 → 即座に性能推移表示 → 次アクション選択（Step 2A/2B は並行処理のまま完了）

**対応フィードバック**: I-6: Phase 5 の推奨判定に Phase 6 デプロイ選択が依存するが、フィールド名不一致の可能性

**変更内容**:
- 344行付近に Phase 5 → Phase 6 変数マッピングセクションを追加:
  - Phase 5 返答フォーマット（recommended, reason, convergence, scores, variants, deploy_info, user_summary）と Phase 6 Step 1 で使用する変数名の対応を明記
  - 例: `recommended` → `{recommended_prompt_name}`, `deploy_info` → `{recommended_variation_info}`

**対応フィードバック**: I-8: Phase 3 全失敗時のベースライン除外リスク

**変更内容**:
- 289-308行: Phase 3 評価失敗時の処理ロジックを修正
  - 現在: ベースライン失敗時も「除外して続行」を選択可能
  - 改善後: ベースライン失敗時は「再試行」または「中断」のみに制限（除外オプションを削除）

**対応フィードバック**: I-4: Phase 0 Step 4 批評エージェントのフィードバックファイル処理が複雑

**変更内容**:
- 127-144行: Step 4 の4並列批評 → Step 5 の統合処理パターンを変更
  - 現在: 各批評エージェントが feedback ファイル保存 + SendMessage で件数返答 → 親が4ファイル Read して統合
  - 改善後: 各批評エージェントが feedback ファイル保存 + SendMessage で件数返答 → 統合サブエージェント（templates/perspective/consolidate-feedback.md）に委譲

### 2. templates/phase4-scoring.md（修正）
**対応フィードバック**: I-2: Phase 4 scoring-rubric.md の並列重複 Read

**変更内容**:
- 1-3行: `{scoring_rubric_path}` の Read 削除
- 手順1を削除し、scoring-rubric.md の全文（70行）をテンプレートに埋め込む
  - 埋め込み内容: 検出判定基準（○△×）、スコア計算式、ボーナス/ペナルティ、安定性閾値、推奨判定基準、収束判定
  - パス変数から `{scoring_rubric_path}` を削除

### 3. templates/phase3-evaluation.md（修正）
**対応フィードバック**: I-3: Phase 3 評価実行のコンテキスト消費

**変更内容**:
- 1-12行: プロンプト内容を親から直接受け取る形式に変更
  - 現在: 手順1で `{prompt_path}` を Read して内容取得
  - 改善後: 手順1を「以下のプロンプト内容に従ってタスクを実行してください: {prompt_content}」に変更
  - パス変数 `{prompt_path}` を削除し、`{prompt_content}` に置き換え
  - SKILL.md の Phase 3 サブエージェント起動箇所（285行付近）で、親が事前に Read した内容を `{prompt_content}` として渡す

### 4. templates/phase1a-variant-generation.md（修正）
**対応フィードバック**: I-7: Phase 1A Step 6 の「ギャップが大きい次元」の判定基準未定義

**変更内容**:
- 21行: 「ギャップが大きい次元」の判定基準を明示
  - 現在: 「ギャップに基づき、approach-catalog.md からギャップが大きい次元の2つの独立変数を選定する」
  - 改善後: 「ギャップスコアを6次元で算出し（スコア = 推奨値 - 現在値）、スコア上位2次元を選択する。同点の場合は proven-techniques.md の効果データが高い次元を優先」

**対応フィードバック**: I-5: Phase 1A/1B approach-catalog.md の全文 Read

**変更内容**:
- 3-5行: `{approach_catalog_path}` の Read 削除
- パス変数から `{approach_catalog_path}` を削除
- 7行: 必要情報（バリエーション ID と構造変更内容のマッピング）を親から受け取る形式に変更
  - 新規パス変数 `{selected_variations_info}` を追加（親が approach-catalog.md から抽出した情報のみを渡す）
  - SKILL.md の Phase 1A 起動箇所（208行付近）で、親が approach-catalog.md を Read し、必要な2バリエーション分の情報のみを抽出して渡す

### 5. templates/phase1b-variant-generation.md（修正）
**対応フィードバック**: I-5: Phase 1A/1B approach-catalog.md の全文 Read

**変更内容**:
- 13行および25行: approach-catalog.md の Read を条件分岐から削除
  - 現在: Broad モード時は Read しない。Deep モード時は全文 Read
  - 改善後: 全モードで approach-catalog.md を Read せず、Deep モード時のみ親が必要情報を抽出して渡す
  - パス変数から `{approach_catalog_path}` を削除
  - 新規パス変数 `{selected_variations_info}` を追加（Deep モード時のみ値が設定される。Broad モード時は空文字列）
  - SKILL.md の Phase 1B 起動箇所（228行付近）で、Deep モード時のみ親が approach-catalog.md を Read し、選定バリエーションの情報のみを抽出して渡す

### 6. SKILL.md（修正：I-4 の実装詳細）
**対応フィードバック**: I-4: Phase 0 Step 4 批評エージェントのフィードバックファイル処理が複雑

**変更内容**:
- 136-144行: Step 5 の統合処理を親からサブエージェントに委譲
  - 現在の処理:
    ```
    1. 各 SendMessage から重大問題件数を取得
    2. 合計が0件の場合は再生成スキップ
    3. 合計が1件以上の場合: 4ファイルを Read → フィードバック統合 → {user_requirements} に追記 → perspective 再生成
    ```
  - 改善後:
    ```
    1. 各 SendMessage から重大問題件数を取得
    2. 合計が0件の場合は再生成スキップ
    3. 合計が1件以上の場合: 統合サブエージェント（templates/perspective/consolidate-feedback.md）を Task で起動
       - 統合サブエージェントが4ファイル Read → 統合 → 統合結果ファイル保存 → 1行返答
       - 親は統合結果ファイルを Read → {user_requirements} に追記 → perspective 再生成
    ```

## 新規作成ファイル

| ファイル | 目的 | 対応フィードバック |
|---------|------|------------------|
| templates/perspective/consolidate-feedback.md | 4並列批評結果の統合処理（親コンテキスト負荷削減） | I-4 |

**templates/perspective/consolidate-feedback.md の内容**:
```markdown
## パス変数
- {feedback_completeness_path}: perspective-feedback-completeness.md の絶対パス
- {feedback_clarity_path}: perspective-feedback-clarity.md の絶対パス
- {feedback_effectiveness_path}: perspective-feedback-effectiveness.md の絶対パス
- {feedback_generality_path}: perspective-feedback-generality.md の絶対パス
- {consolidated_feedback_path}: 統合フィードバックの保存先パス

以下の手順でフィードバックを統合してください:

1. Read で4つの批評フィードバックファイルを読み込む
2. 各観点の重大な問題を統合し、重複を除去する
3. 統合結果を {consolidated_feedback_path} に保存する（観点別にセクション分け）
4. 以下のフォーマットで1行のみ返答する:

統合完了: {重大な問題の総件数}件
```

## 削除推奨ファイル

なし

## 実装順序

1. **templates/perspective/consolidate-feedback.md の新規作成** — I-4 のサブエージェント委譲に必要
2. **templates/phase4-scoring.md の修正** — I-2（scoring-rubric.md 埋め込み）
3. **templates/phase1a-variant-generation.md の修正** — I-5, I-7（approach-catalog.md Read 削除、ギャップ判定基準明示）
4. **templates/phase1b-variant-generation.md の修正** — I-5（approach-catalog.md Read 削除）
5. **templates/phase3-evaluation.md の修正** — I-3（プロンプト内容を親から受け取る）
6. **SKILL.md の修正** — I-1, I-4, I-6, I-8, および Phase 1A/1B/3 のテンプレート変更に対応するパス変数・サブエージェント起動パターンの更新

依存関係の検出方法:
- templates/perspective/consolidate-feedback.md（新規）は SKILL.md の Phase 0 Step 5 で参照されるため、SKILL.md の修正前に作成
- テンプレートの修正（2-5）は SKILL.md の修正（6）で参照されるため、テンプレート修正を先に実施
- テンプレート間の依存はないため、2-5 は並列実施可能

## 注意事項
- I-1（Step 2C の並列化）実装時、Step 2A/2B の完了確認処理を削除しないこと（並列起動のまま、完了待機せずに Step 2C を実行）
- I-3（Phase 3 プロンプト内容受け渡し）実装時、SKILL.md の Phase 3 起動箇所でプロンプト全文を Read して `{prompt_content}` として渡すこと
- I-5（approach-catalog.md の部分抽出）実装時、SKILL.md でバリエーション選定後に必要情報のみを抽出するロジックを追加すること
- I-4（フィードバック統合のサブエージェント委譲）実装時、統合結果ファイルのパスを SKILL.md で定義すること（例: `.agent_bench/{agent_name}/perspective-feedback-consolidated.md`）
- 全変更において、既存の7行サマリ返答フォーマット、パス変数命名規則、ファイル配置パターンを維持すること
