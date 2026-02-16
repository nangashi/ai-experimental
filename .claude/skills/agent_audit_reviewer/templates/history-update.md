以下の手順で history.md を更新してください:

1. Read で以下を読み込む:
   - {history_path} （現在の最適化履歴）
   - {report_save_path} （今回の比較レポート）
   - {selected_scoring_path} が空でない場合: Read で読み込む（選択されたバリアントの採点ファイル — エラー分析を含む）

2. history.md を以下のルールで更新する:

### Agent Info セクション
   - Rounds を +1
   - {selected_name} が現在ベストと異なる場合: Current Best を更新する（プロンプトファイル名とスコアを更新）

### Current Error Analysis セクション
   - {selected_scoring_path} が空でない場合（= 新しいベストが選択された場合）:
     - 採点ファイルの「エラー分析（抽象的）」セクション内の以下を抽出してこのセクションを上書きする:
       - 「Missed/Partial by Category」テーブル
       - 「Improvement Directions」リスト
       - 「Strengths to Preserve」リスト
   - {selected_scoring_path} が空の場合（= 現在ベストが維持された場合）:
     - このセクションは変更しない

### Round History テーブル
   - 今回のラウンドのエントリを追記する:
     | R{round_number} | {selected_name} | {score} | {SD} | {key_change} | {remaining_errors_summary} |
   - {key_change}: 比較レポートの考察から変更内容の1行要約を抽出する。現在ベスト維持の場合は "no improvement"
   - {remaining_errors_summary}: 採点の見逃し+部分検出カテゴリ数の合計

### Effective Changes テーブル
   - 推奨バリアントの変更（現在ベストより +0.5pt 以上改善）があれば追記する:
     | {変更内容} | {効果pt} | {SD} | R{round_number} | {対象カテゴリ} |

### Ineffective Changes テーブル
   - 現在ベスト以下のバリアントの変更があれば追記する:
     | {変更内容} | {効果pt} | {SD} | R{round_number} | {対象カテゴリ} |
   - このテーブルは最大15行。超過時は最も効果差が小さい（|effect| が最小）エントリを削除する

3. 更新した history.md を Write で保存する

4. 以下のフォーマットで確認のみ返答する:

history.md 更新完了（Round {round_number}, Best: {prompt_name}, Score: {X.X}）
