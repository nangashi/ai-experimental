# Prompt Engineering Findings

Agent/reviewer prompt structure design guidelines covering decomposition, technique selection, and bias avoidance.

## 推論モデルでのCoT明示指示の省略

- **scope**: 推論モデル（o3-mini, o4-mini等）を対象としたプロンプト設計時
- **action**: 明示的な"Step 1:... Step 2:..."のようなCoT指示を削除する。推論の方向性のみ示す軽量なガイダンスにとどめる。
- **rationale**: 推論モデルは内部で既にCoT的処理を行うため、明示的指示は冗長。推論モデルでのCoT効果は+2.9〜3.1%と限定的であり、応答時間が+20〜80%増加する。Gemini Flash 2.5では-3.3%と逆効果。
- **conditions**: 非推論モデル（GPT-4o-mini等）では+4.4〜13.5%の改善があるため、モデル種別を確認する。
- **source**: docs/knowledge/prompt-design.md

## 剛性的ステップ指定の回避

- **scope**: 複雑な多段推論タスクでの指示設計時
- **action**: "Step 1:... Step 2:..."のような剛性的ステップ指定を避け、"Think through the design holistically"のような方向性のみを示す柔軟なガイダンスを使用する。
- **rationale**: 剛性的ステップ指定はステップ完了バイアスを生み、探索を抑制する。柔軟なガイダンス形式の方が推論の質が高い。
- **source**: docs/knowledge/prompt-design.md

## Few-shotの例数制限

- **scope**: Few-shot prompting を使用する場合
- **action**: 例を1-2例に制限する。2例を超える場合は例数を削減する。
- **rationale**: 2例が最適であり、それ以上は満足化バイアスを引き起こす。複雑なレビュー・評価タスクでは、テンプレートバイアスにより6例使用時に重大検出率が100%→0%に低下した実験結果がある。
- **source**: docs/knowledge/prompt-design.md

## 推論モデルでのFew-shot回避

- **scope**: 推論モデル使用時のプロンプト設計
- **action**: ゼロショットで十分な場合はFew-shotを使用しない。推論モデルでは5-shotでベースラインより劣化する。
- **rationale**: 推論モデルは5-shotでベースラインより劣化することが確認されている。出力フォーマット明示が必要な場合（精度0%→90%の改善事例）を除き、ゼロショットが推奨される。
- **source**: docs/knowledge/prompt-design.md

## ペルソナ指示の詳細化

- **scope**: ロール/ペルソナ指示を使用する場合
- **action**: 単純な"You are a lawyer"ではなく、詳細かつドメイン固有の記述を含むペルソナ指示を作成する。LLM生成ペルソナの使用を検討する。
- **rationale**: 2025年の複数研究により、単純ペルソナは改善なし、時に劣化することが判明。GPT-4-turbo × 2,000 MMLU問題 × 12ペルソナのテストでは「バカ」ペルソナが「天才」を上回った。詳細かつドメイン固有の記述が必要であり、LLM生成ペルソナが人間作成のものを上回る。
- **conditions**: 創作・オープンエンドタスク（トーン・スタイル制御）や一貫性検証（パターン照合視点の強制、+3.0pt）では有効。
- **source**: docs/knowledge/prompt-design.md

## カテゴリ別分解の優先

- **scope**: 複雑な問題のプロンプト設計時
- **action**: 複雑な問題をドメイン別・カテゴリ別にサブ問題へ分解する。検出と報告のフェーズを分離する。
- **rationale**: カテゴリ別分解は安定性最高（SD=0.0）を記録。検出と報告の分離で+2.0〜2.5pt、早期フィルタリング防止の効果がある。エージェント的設定での逐次的推論に特に有効。
- **source**: docs/knowledge/prompt-design.md

## 過剰構造化の回避

- **scope**: プロンプトの構造化レベルを決定するとき
- **action**: 軽量ヒント2件を上限とする。チェックリスト統合、厳格カテゴリ化は避ける。カテゴリ分解レベルに留める。
- **rationale**: 構造化の量と性能は逆U字の関係にある。過剰構造化は一貫して逆効果であり、チェックリスト統合で-1.75pt、厳格カテゴリで-4.5ptの低下が確認されている。軽量ヒント2件が最適閾値、3件以上で逆効果。
- **source**: docs/knowledge/prompt-design.md

## 推論精度優先時のNL-to-Formatアプローチ

- **scope**: 推論の質が最優先で、かつ構造化出力も必要な場合
- **action**: 自然言語で回答させ、後からフォーマット変換するNL-to-Formatアプローチを採用する。
- **rationale**: フォーマット制約が厳しいほど推論能力の低下が大きい。推論精度最優先なら、自然言語で回答させ後からフォーマット変換する方が有効。
- **source**: docs/knowledge/prompt-design.md

## コンテキスト改善のテクニック工夫に対する優先

- **scope**: プロンプトエンジニアリングとコンテキストエンジニアリングの選択
- **action**: 言葉遣いや構造のテクニックを工夫する前に、まずタスクに必要な情報をコンテキストに提供することを優先する。
- **rationale**: プロンプトエンジニアリング改善の85%はコンテキスト改善で達成可能。適切な情報を提供することがテクニック選択より高い効果を持つ。
- **source**: docs/knowledge/context-design.md

## 早期解決試行の抑制指示

- **scope**: 要件が複数ターンで段階的に明らかになるタスク
- **action**: 「すべての要件が提示されるまで完全な解決策を提案しない」という明示的な指示をプロンプトに含める。
- **rationale**: マルチターン劣化の主原因の1つは「早期解決試行」（要件が揃う前に仮定を置いて完全な回答を生成）。この指示により仮定の蓄積と誤ったアンカリングを防止できる。
- **source**: docs/knowledge/context-design.md

## 指示ファイルの削除テストによる最小化

- **scope**: 永続的な指示ファイルの作成・編集
- **action**: 各行について「これを削除するとClaudeがミスするか？」と問い、NOなら削除する。コードを読めば分かること、標準的な言語規約、詳細なAPIドキュメント、「クリーンなコードを書け」等の自明な指示を含めない。
- **rationale**: Anthropic公式のCLAUDE.mdベストプラクティス。肥大化したCLAUDE.mdファイルはClaudeに実際の指示を無視させる。
- **source**: docs/knowledge/context-design.md

## 言語一貫性の厳守

- **scope**: プロンプトの言語選択時
- **action**: 完全英語 or 完全日本語のどちらかに統一する。混合を避ける。
- **rationale**: 混合は検出パターンシフトと安定性悪化を引き起こす。
- **source**: docs/knowledge/prompt-design.md

## セキュリティレビューでのCWE番号指定

- **scope**: セキュリティレビュー観点の生成、またはコード生成時のセキュリティ指示
- **action**: セキュリティレビューには「セキュリティを確認せよ」のようなgenericな指示ではなく、具体的なCWE番号を含めて回避を指示する。
- **rationale**: Claude Opus 4.5 + Thinkingを用いた実験で、セキュリティプロンプティングなしで56%のセキュアコード生成率が、特定のCWE番号を指定すると69%に向上（+13pp）。AI生成コードの45%がセキュリティテストに不合格（86%がXSS防御に失敗、88%がログインジェクションに脆弱）。
- **source**: docs/knowledge/ai-code-quality.md


