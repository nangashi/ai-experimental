# エージェントグループ分類基準

エージェント定義の **主たる機能** に注目して分類する。以下の判定基準を **hybrid → evaluator → producer → unclassified** の順に評価し、最初に該当したグループに分類する。

## evaluator 特徴（4項目）
- 評価基準・チェックリスト・検出ルールが定義されている
- 入力に対して問題点・改善点・findings を出力する構造がある
- 重要度・深刻度（severity, critical, significant 等）による分類がある
- 評価スコープ（何を評価するか/しないか）が定義されている

## producer 特徴（4項目）
- ステップ・手順・ワークフローに従って成果物を作成する構造がある
- 出力がファイル・コード・文書・計画などの成果物である
- 入力を変換・加工・生成する処理が主体である
- ツール操作（Read/Write/Edit/Bash 等）による作業手順が記述されている

## 判定ルール
1. evaluator 特徴が3つ以上 **かつ** producer 特徴が3つ以上 → **hybrid**
2. evaluator 特徴が3つ以上 → **evaluator**
3. producer 特徴が3つ以上 → **producer**
4. 上記いずれにも該当しない → **unclassified**
