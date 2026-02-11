以下の手順で採点を実行してください:

1. Read で以下を読み込む:
   - {scoring_rubric_path} （採点基準）
   - {answer_key_path} （正解キー）
   - {perspective_path} （観点定義）
   - {result_run1_path} （Run1結果）
   - {result_run2_path} （Run2結果）
2. 採点基準と正解キーに従い、各結果を採点する
3. 詳細な採点結果（問題別検出マトリクス、ボーナス/ペナルティ詳細）を Write で {scoring_save_path} に保存する
4. 以下のコンパクトなスコアサマリのみ返答する:

{prompt_name}: Mean={X.X}, SD={X.X}
Run1={X.X}(検出{X.X}+bonus{N}-penalty{N}), Run2={X.X}(検出{X.X}+bonus{N}-penalty{N})
