以下の手順で採点を実行してください:

1. Read で以下を読み込む:
   - {scoring_rubric_path} （採点基準 — 計算式・判定基準）
   - {rubric_path} （テストシナリオのルーブリック — 基準ごとの Full/Partial/Miss 条件）
   - {result_paths} に含まれる全結果ファイル（Run1/Run2 × 全シナリオ）
2. 各シナリオ × 各Runについて:
   - ルーブリックの基準ごとに 0/1/2 で判定する
   - criterion_score = judge_rating × weight を算出する
   - scenario_score = Σ(criterion_scores) / max_possible × 10 で 0-10 に正規化する
3. 各Run の run_score = mean(全scenario_scores) を算出する
4. variant_mean = mean(run1, run2) と variant_sd = stddev(run1, run2) を算出する
5. 詳細な採点結果（シナリオ別×Run別の基準判定マトリクス、スコア内訳）を Write で {scoring_save_path} に保存する
6. 以下のコンパクトなスコアサマリのみ返答する:

{prompt_name}: Mean={X.XX}, SD={X.XX}
Run1={X.XX}, Run2={X.XX}
T01={X.X}(r1/r2), T02={X.X}(r1/r2), ...
