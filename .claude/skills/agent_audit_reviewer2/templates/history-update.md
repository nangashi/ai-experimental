以下の手順で history.md を更新してください:

1. Read で以下を読み込む:
   - {history_path} （現在の最適化履歴）
   - {report_save_path} （今回の比較レポート）
   - {selected_scoring_doc1_path} が空でない場合: Read で読み込む（文書1の採点ファイル）
   - {selected_scoring_doc2_path} が空でない場合: Read で読み込む（文書2の採点ファイル）

2. history.md を以下のルールで更新する:

### Agent Info セクション
   - Rounds を +1
   - {selected_name} が現在ベストと異なる場合: Current Best を更新（名前とスコア）

### Item Discrimination セクション
   新しいベストが選択された場合のみ更新:
   - 各文書の採点ファイルの検出マトリクスから各問題の Run1/Run2 結果を取得する
   - 全4 Runの結果から識別力を再判定する:
     - 4Run全て○ → 低（天井）
     - 4Run全て× → 低（床）
     - 3Run以上○、残り△ → 中（安定検出）
     - ○/△/×が混在 → 高
     - 3Run以上×、残り△ → 中（安定未検出）

### Current Error Analysis セクション
   新しいベストが選択された場合: 2文書の採点ファイルのエラー分析を統合してこのセクションを上書きする
   現在ベストが維持された場合: 変更しない

### Category Detection Rates セクション
   新しいベストが選択された場合: 2文書の採点ファイルからカテゴリ別検出率を統合して上書きする

### Round History テーブル
   今回のラウンドのエントリを追記する

### Effective Changes テーブル
   推奨バリアントの変更（現在ベストより +0.5pt 以上改善かつ回帰なし）があれば追記

### Ineffective Changes テーブル
   現在ベスト以下のバリアント、または回帰があったバリアントの変更を追記
   最大15行。超過時は |effect| が最小のエントリを削除

3. 更新した history.md を Write で保存する

4. 以下のフォーマットで返答する:

history.md 更新完了（Round {round_number}, Best: {prompt_name}, Score: {X.X}）
