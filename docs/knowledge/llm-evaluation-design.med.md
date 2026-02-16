# Instruction Extract: llm-evaluation-design

source: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/docs/knowledge/llm-evaluation-design.md
extracted: 2026-02-16
items: 11

---

## KE-001: 位置バイアス対策としての提示順序ランダム化

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance)
- **scope**: LLMによるペアワイズ比較評価を設計するとき
- **action**: 評価対象の提示順序をランダム化する。固定順序での比較を避ける。
- **rationale**: 提示順序の入れ替えで精度が10%以上変動する位置バイアスが存在する。固定順序は系統的なバイアスを受ける。

---

## KE-002: 生成と評価のモデル分離

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance)
- **scope**: LLM出力の評価・レビューワークフローを設計するとき
- **action**: 生成と評価で同一モデルを使用しない。レビュー用エージェントと生成用エージェントを分離する。
- **rationale**: 生成と同じモデルがレビューする場合、自己選好バイアス（パープレキシティが低いテキストを高評価）により自分のミスを検出できない。自分が生成したパターンを「正しい」と認識する傾向がある。

---

## KE-003: セルフレビュー時の明示的フレーミング

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance)
- **scope**: 同一モデルでのセルフレビューが構造上避けられないとき
- **action**: 「このコードを初めて見る人の視点で」と明示的にフレーミングする。
- **rationale**: 自己選好バイアスに対抗するため、視点の転換を強制する必要がある。

---

## KE-004: 批判的評価フレーミング

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance)
- **scope**: LLMに評価タスクを指示するとき
- **action**: 「評価する」ではなく「批判的に評価し、代替案を提案する」とフレーミングする。
- **rationale**: sycophancy傾向（ユーザーの好みに迎合する傾向）に対抗できる。

---

## KE-005: ルブリック・スコア設計時のバイアス前提

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance)
- **scope**: LLM評価用のルブリックやスコアリング基準を設計するとき
- **action**: ルブリックの順序とスコアIDラベルが独立にバイアスを発生させることを前提に設計する。出力長で正規化してバリアント比較する。
- **rationale**: スコアリングバイアスの3サブタイプ（ルブリックの順序、スコアIDのラベル、参照回答の有無）がそれぞれ独立に判定を変動させる。GPT-4oでも摂動により人間との相関が最大0.2変動する。

---

## KE-006: 回答匿名化による評価バイアス防止

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance)
- **scope**: 複数のバリアントや並列レビュー結果をクロス評価するとき
- **action**: 回答からソース帰属を除去して匿名化する。
- **rationale**: 回答のソースが分かるとidentity-driven biasが発生する。匿名化により構造的に防止できる。

---

## KE-007: 信頼度スコアの鵜呑み禁止

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance)
- **scope**: LLMの自己評価や信頼度スコアを判断材料として使用するとき
- **action**: LLMの自己評価の信頼度スコアを鵜呑みにしない。別の検証手段と組み合わせる。
- **rationale**: 84.3%のシナリオでLLMは過信する（9 LLM、351シナリオ中296で過信）。最も精度の高いモデルでも正解時と不正解時の信頼度にほとんど差がない。推論強化はキャリブレーションを悪化させる。

---

## KE-008: ディストラクター効果の活用

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance)
- **scope**: LLMによる評価タスクを設計するとき
- **action**: もっともらしい誤答選択肢を明示的に含める。
- **rationale**: ディストラクター効果により精度が最大460%改善、キャリブレーション誤差が90%減少する。モデルがより慎重に回答を検証するようになる。

---

## KE-009: CoT長に基づく品質判断の禁止

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance)
- **scope**: LLMの推論トレース（CoT）を品質評価の材料とするとき
- **action**: 長い推論を良い推論と見なさない。出力は推論トレースではなく最終結果で検証する。
- **rationale**: 不忠実なCoTは体系的に長い（Claude 3.7 Sonnet — 不忠実: 2,064トークン vs 忠実: 1,439トークン。DeepSeek R1 — 不忠実: 6,003 vs 忠実: 4,737）。バイアスタイプで忠実性が劇的に異なる（Sycophancy型: 60%忠実、報酬ハッキング型: 0%忠実）。

---

## KE-010: Faithfulness評価による引用検証

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance)
- **scope**: RAGシステムでLLMが生成した回答の信頼性を検証するとき
- **action**: 回答の各文が引用パッセージによって裏付けられているか、引用が主張された事実を実際に含んでいるかを検証する。裏付けのない主張にペナルティを課す。
- **rationale**: Faithfulness評価（コンテキスト↔レスポンスの忠実性）により、ハルシネーションを検出できる。引用マッピング検証でspan-levelの正確性を文単位で測定可能。

---

## KE-011: Self-Consistency検証の適用

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance)
- **scope**: 評価・検証タスクで推論結果の信頼性を担保する必要があるとき
- **action**: 複数の推論パスを生成し、最も一致する回答を選択する。単一の推論結果を鵜呑みにしない。
- **rationale**: GSM8K: +17.9%、SVAMP: +11.0%、AQuA: +12.2%の精度向上。複数パスの合意で信頼性を担保できる。
