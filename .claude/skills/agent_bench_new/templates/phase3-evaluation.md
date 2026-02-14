以下の手順でエージェント定義を評価してください:

1. Read で {prompt_path} を読み込み、その内容に従ってタスクを実行してください
2. Read で {test_doc_path} を読み込み、処理対象としてください
3. 処理結果を Write で {result_path} に保存してください
4. 最後に「保存完了: {result_path}」とだけ返答してください

## パス変数
- `{prompt_path}`: 評価対象プロンプトの絶対パス
- `{test_doc_path}`: テスト対象文書の絶対パス
- `{result_path}`: 評価結果の保存先パス
