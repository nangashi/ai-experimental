以下の手順で採点を実行してください:

1. Read で {scoring_rubric_path} （採点基準）を読み込む
2. Read で {answer_key_path} （正解キー）を読み込む
3. Read で {perspective_path} （観点定義）を読み込む
4. Read で {result_run1_path} （Run1結果）と {result_run2_path} （Run2結果）を読み込む
5. 採点基準の検出判定基準とスコア計算式に従い、各結果を採点する
6. 詳細な採点結果（問題別検出マトリクス、ボーナス/ペナルティ詳細）を Write で {scoring_save_path} に保存する
7. 以下のコンパクトなスコアサマリのみ返答する:

{prompt_name}: Mean={X.X}, SD={X.X}
Run1={X.X}(検出{X.X}+bonus{N}-penalty{N}), Run2={X.X}(検出{X.X}+bonus{N}-penalty{N})
