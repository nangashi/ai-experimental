以下の手順で比較レポートを作成し、推奨判定を行ってください:

1. Read で以下を読み込む:
   - {scoring_rubric_path} （採点基準 — 推奨判定基準・収束判定を含む）
   - {knowledge_path} （現在のナレッジ）
   - 以下の採点結果ファイル:
     {scoring_file_paths}
2. scoring-rubric.md の推奨判定基準に従い、推奨プロンプトを判定する
3. scoring-rubric.md の収束判定基準に従い、収束判定を行う
4. 比較レポートを生成して {report_save_path} に保存する。必要なセクション:
   - 実行条件、比較対象、スコアマトリクス（問題別検出+ボーナス/ペナルティ詳細）、スコアサマリ、推奨判定、考察（独立変数ごとの効果分析、次回への示唆）
5. knowledge.md は更新しないこと
6. 以下のフォーマットでサマリのみ返答する:

recommended: {prompt名}
reason: {判定根拠1行}
convergence: {継続推奨 or 収束の可能性あり}
scores: {prompt1}={X.XX}(SD={X.XX}), {prompt2}={X.XX}(SD={X.XX}), ...
variants: {variant1}={Variation ID, 変更内容要約}, {variant2}={Variation ID, 変更内容要約}
deploy_info: {推奨プロンプトの Variation ID と独立変数}
user_summary: {ユーザー向け結果1行サマリ}
