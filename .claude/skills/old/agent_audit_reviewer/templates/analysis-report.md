以下の手順で比較レポートを作成し、推奨判定を行ってください:

1. Read で以下を読み込む:
   - {scoring_rubric_path} （採点基準 — 推奨判定基準・収束判定を含む）
   - {history_path} （最適化履歴 — 現在のベストスコアと過去の推移を含む）
   - 以下の採点結果ファイル:
     {scoring_file_paths}
   - 以下のプロンプトファイル（Benchmark Metadata 抽出用）:
     {prompt_file_paths}

2. 各プロンプトファイルの先頭にある `<!-- Benchmark Metadata ... -->` ブロックから以下を抽出する:
   - `Change`: 変更内容の1行要約
   - `Target`: 対象カテゴリ
   - `Rationale`: 期待効果
   - `Side-effect-risk`: 想定副作用リスク

3. history.md の「Agent Info」セクションから現在のベストプロンプト名とそのスコアを取得する（これがベースラインとなる。再評価はしない）

4. 各バリアントのスコアを現在のベストスコアと比較する:
   - scoring-rubric.md の推奨判定基準に従い推奨プロンプトを判定する
   - scoring-rubric.md の収束判定基準に従い収束判定を行う

5. 比較レポートを生成して {report_save_path} に保存する。必要なセクション:
   - 実行条件（ラウンド番号、テスト文書、比較対象）
   - スコア比較テーブル（現在ベスト vs 各バリアント: Mean, SD, 各Run）
   - カテゴリ別検出改善/悪化マトリクス（各バリアントで改善/悪化したカテゴリ）
   - バリアント別分析（per-variant で以下を記載）:
     - 変更内容と期待効果（Benchmark Metadata の Change + Rationale）
     - 実績スコアとカテゴリ別改善/悪化
     - 解釈（期待効果と実績の一致/乖離の原因分析）
     - 副作用（Benchmark Metadata の Side-effect-risk vs 実際に観察された副作用）
   - リスク評価:
     - 過学習リスク（ボーナス依存度 = ボーナス点 / 総合スコア、検出スコア vs 総合スコアの乖離）
     - 注意分散リスク（改善カテゴリと悪化カテゴリのトレードオフの有無）
     - 汎化リスク（固定テスト文書への特化度合いの推測）
   - 推奨判定と根拠
   - 考察（次回への示唆）

6. history.md は更新しないこと

7. 以下のフォーマットで返答する:

```
## バリアント別分析

### {variant_name_1}
- 変更内容: {Change from BM}
- 期待効果: {Rationale from BM}
- 実績: Mean={X.X}(SD={X.X}), vs current-best {+/-X.X}pt
- 解釈: {期待と実績の一致/乖離の原因推測}
- 副作用: 想定={Side-effect-risk from BM} → 実際={観察された副作用の有無と内容}

### {variant_name_2}
（同上）

## 推奨
- recommended: {プロンプト名}
- reason: {判定根拠。過学習リスク・ボーナス依存度等を含む}
- convergence: {継続推奨 or 収束の可能性あり}
- scores: current-best={X.XX}(SD={X.XX}), {各バリアント名}={X.XX}(SD={X.XX}), ...
- risk_assessment: {過学習リスク、注意分散リスク、汎化リスクの総合評価}
```
