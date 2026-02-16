# LLM Evaluation Design

LLM出力の評価ワークフローやルブリック設計における、バイアス対策と信頼性確保の指針。

## 位置バイアス対策としての提示順序ランダム化

- **scope**: LLMによるペアワイズ比較評価を設計するとき
- **action**: 評価対象の提示順序をランダム化する。固定順序での比較を避ける。
- **rationale**: 提示順序の入れ替えで精度が10%以上変動する位置バイアスが存在する。固定順序は系統的なバイアスを受ける。
- **source**: docs/knowledge/llm-evaluation-design.md

## 生成と評価のモデル分離

- **scope**: LLM出力の評価・レビューワークフローを設計するとき
- **action**: 生成と評価で同一モデルを使用しない。レビュー用エージェントと生成用エージェントを分離する。
- **rationale**: 生成と同じモデルがレビューする場合、自己選好バイアス（パープレキシティが低いテキストを高評価）により自分のミスを検出できない。自分が生成したパターンを「正しい」と認識する傾向がある。
- **source**: docs/knowledge/llm-evaluation-design.md

## セルフレビュー時の明示的フレーミング

- **scope**: 同一モデルでのセルフレビューが構造上避けられないとき
- **action**: 「このコードを初めて見る人の視点で」と明示的にフレーミングする。
- **rationale**: 自己選好バイアスに対抗するため、視点の転換を強制する必要がある。
- **source**: docs/knowledge/llm-evaluation-design.md

## 批判的評価フレーミング

- **scope**: LLMに評価タスクを指示するとき
- **action**: 「評価する」ではなく「批判的に評価し、代替案を提案する」とフレーミングする。
- **rationale**: sycophancy傾向（ユーザーの好みに迎合する傾向）に対抗できる。
- **source**: docs/knowledge/llm-evaluation-design.md

## ルブリック・スコア設計時のバイアス前提

- **scope**: LLM評価用のルブリックやスコアリング基準を設計するとき
- **action**: ルブリックの順序とスコアIDラベルが独立にバイアスを発生させることを前提に設計する。出力長で正規化してバリアント比較する。
- **rationale**: スコアリングバイアスの3サブタイプ（ルブリックの順序、スコアIDのラベル、参照回答の有無）がそれぞれ独立に判定を変動させる。GPT-4oでも摂動により人間との相関が最大0.2変動する。
- **source**: docs/knowledge/llm-evaluation-design.md

## 回答匿名化による評価バイアス防止

- **scope**: 複数のバリアントや並列レビュー結果をクロス評価するとき
- **action**: 回答からソース帰属を除去して匿名化する。
- **rationale**: 回答のソースが分かるとidentity-driven biasが発生する。匿名化により構造的に防止できる。
- **source**: docs/knowledge/llm-evaluation-design.md

## 信頼度スコアの鵜呑み禁止

- **scope**: LLMの自己評価や信頼度スコアを判断材料として使用するとき
- **action**: LLMの自己評価の信頼度スコアを鵜呑みにしない。別の検証手段と組み合わせる。
- **rationale**: 84.3%のシナリオでLLMは過信する（9 LLM、351シナリオ中296で過信）。最も精度の高いモデルでも正解時と不正解時の信頼度にほとんど差がない。推論強化はキャリブレーションを悪化させる。
- **source**: docs/knowledge/llm-evaluation-design.md

## CoT長に基づく品質判断の禁止

- **scope**: LLMの推論トレース（CoT）を品質評価の材料とするとき
- **action**: 長い推論を良い推論と見なさない。出力は推論トレースではなく最終結果で検証する。
- **rationale**: 不忠実なCoTは体系的に長い（Claude 3.7 Sonnet — 不忠実: 2,064トークン vs 忠実: 1,439トークン。DeepSeek R1 — 不忠実: 6,003 vs 忠実: 4,737）。バイアスタイプで忠実性が劇的に異なる（Sycophancy型: 60%忠実、報酬ハッキング型: 0%忠実）。
- **source**: docs/knowledge/llm-evaluation-design.md
