以下の手順で比較レポートを作成し、推奨判定を行ってください:

1. Read で以下を読み込む:
   - {scoring_rubric_path} （採点基準 — 推奨判定基準・回帰加重差分・収束判定を含む）
   - {history_path} （最適化履歴 — 現在のベストスコアと過去の推移を含む）
   - 以下の採点結果ファイル（各バリアント × 2文書 = 4ファイル）:
     {scoring_file_paths}
   - 以下のプロンプトファイル（Benchmark Metadata 抽出用）:
     {prompt_file_paths}

2. 各プロンプトファイルの `<!-- Benchmark Metadata ... -->` から以下を抽出する:
   - `Change`, `Target`, `Rationale`, `Predicted-regression`

3. history.md の「Agent Info」から現在ベストのスコアとカテゴリ別検出率を取得する

4. 各バリアントの統合スコアを計算する:
   - overall_mean = average(doc1_run1, doc1_run2, doc2_run1, doc2_run2)
   - overall_sd = stddev(doc1_run1, doc1_run2, doc2_run1, doc2_run2)
   - cross_doc_gap = |doc1_mean - doc2_mean|
   - カテゴリ別検出率 = 2文書の合算

5. scoring-rubric.md の推奨判定基準に従い推奨プロンプトを判定する:
   - **回帰加重差分**を計算する:
     ```
     adjusted_diff = raw_mean_diff - 1.5 × Σ(regressed_category_rate_drops)
     ```
   - 回帰 = カテゴリ検出率が現在ベストから 0.15 以上低下
   - 回帰予測（Benchmark Metadata）と実際の回帰を照合する

6. 比較レポートを {report_save_path} に Write で保存する:
   - スコア比較テーブル（現在ベスト vs 各バリアント: Mean, SD, cross_doc_gap）
   - カテゴリ別検出率比較マトリクス（回帰を赤字相当で明示）
   - バリアント別分析:
     - 変更内容と期待効果
     - 実績スコアとカテゴリ別変化
     - 回帰予測 vs 実際の回帰
     - cross_doc_gap による汎化評価
   - リスク評価（過学習リスク、注意分散リスク、回帰リスク）
   - 推奨判定と根拠
   - 考察

7. 以下のフォーマットで返答する:

```
## バリアント別分析

### {variant_name_1}
- 変更内容: {Change}
- 実績: Mean={X.X}(SD={X.X}), vs current-best {+/-X.X}pt
- カテゴリ変化: {改善カテゴリ} +{rate}, {回帰カテゴリ} -{rate}
- 回帰予測: {predicted} → 実際: {actual}
- cross_doc_gap: {X.X}pt

### {variant_name_2}
（同上）

## 推奨
- recommended: {プロンプト名}
- reason: {判定根拠。回帰加重差分を含む}
- adjusted_diff: {X.XX}pt
- convergence: {継続推奨 or 収束の可能性あり}
- scores: current-best={X.XX}(SD={X.XX}), {各バリアント名}={X.XX}(SD={X.XX}), ...
```
