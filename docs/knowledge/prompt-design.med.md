# Instruction Extract: prompt-design

source: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/docs/knowledge/prompt-design.md
extracted: 2026-02-16
items: 17

---

## KE-001: 推論モデルでのCoT明示指示の省略

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance)
- **scope**: 推論モデル（o3-mini, o4-mini等）を対象としたプロンプト設計時
- **action**: 明示的な"Step 1:... Step 2:..."のようなCoT指示を削除する。推論の方向性のみ示す軽量なガイダンスにとどめる。
- **rationale**: 推論モデルは内部で既にCoT的処理を行うため、明示的指示は冗長である。Wharton大学の研究(2025)により、推論モデルでのCoT効果は+2.9〜3.1%と限定的であり、応答時間が+20〜80%増加する。Gemini Flash 2.5では-3.3%と逆効果になる。
- **conditions**: 非推論モデル（GPT-4o-mini等）では+4.4〜13.5%の改善があるため、モデル種別を確認する必要がある。

---

## KE-002: 剛性的ステップ指定の回避

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance)
- **scope**: 複雑な多段推論タスクでの指示設計時
- **action**: "Step 1:... Step 2:..."のような剛性的ステップ指定を避け、"Think through the design holistically"のような方向性のみを示す柔軟なガイダンスを使用する。
- **rationale**: 剛性的ステップ指定はステップ完了バイアスを生み、探索を抑制する。柔軟なガイダンス形式の方が推論の質が高い。

---

## KE-003: Few-shotの例数制限

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance)
- **scope**: Few-shot prompting を使用する場合
- **action**: 例を1-2例に制限する。2例を超える場合は例数を削減する。
- **rationale**: 2例が最適であり、それ以上は満足化バイアスを引き起こす。複雑なレビュー・評価タスクでは、テンプレートバイアスにより6例使用時に重大検出率が100%→0%に低下した実験結果がある。

---

## KE-004: 推論モデルでのFew-shot回避

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance)
- **scope**: 推論モデル使用時のプロンプト設計
- **action**: ゼロショットで十分な場合はFew-shotを使用しない。推論モデルでは5-shotでベースラインより劣化する。
- **rationale**: 推論モデルは5-shotでベースラインより劣化することが確認されている。出力フォーマット明示が必要な場合（精度0%→90%の改善事例）を除き、ゼロショットが推奨される。

---

## KE-005: ペルソナ指示の詳細化

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance)
- **scope**: ロール/ペルソナ指示を使用する場合
- **action**: 単純な"You are a lawyer"ではなく、詳細かつドメイン固有の記述を含むペルソナ指示を作成する。LLM生成ペルソナの使用を検討する。
- **rationale**: 2025年の複数研究により、単純ペルソナは改善なし、時に劣化することが判明。GPT-4-turbo × 2,000 MMLU問題 × 12ペルソナのテストでは「バカ」ペルソナが「天才」を上回った。詳細かつドメイン固有の記述が必要であり、LLM生成ペルソナが人間作成のものを上回る。
- **conditions**: 創作・オープンエンドタスク（トーン・スタイル制御）や一貫性検証（パターン照合視点の強制、+3.0pt）では有効。

---

## KE-006: カテゴリ別分解の優先

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance)
- **scope**: 複雑な問題のプロンプト設計時
- **action**: 複雑な問題をドメイン別・カテゴリ別にサブ問題へ分解する。検出と報告のフェーズを分離する。
- **rationale**: カテゴリ別分解は安定性最高（SD=0.0）を記録。検出と報告の分離で+2.0〜2.5pt、早期フィルタリング防止の効果がある。エージェント的設定での逐次的推論に特に有効。

---

## KE-007: 感情的刺激の活用

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidage)
- **scope**: 複雑な推論タスク、特に大規模モデルを使用する場合
- **action**: タスクに応じた感情的手がかりをプロンプトに織り込む。バグ修正には緊急性、ブレストには興奮、助言には共感の表現を使用する。汎用ステップバイステップより"Take a deep breath and work on this problem step-by-step"を優先する。
- **rationale**: BIG-Benchタスクで115%の改善を記録。大規模モデルほど恩恵が大きい。"Take a deep breath..."は汎用ステップバイステップより効果的。
- **conditions**: ポジティブ刺激は追従的行動(sycophancy)も増加させる。最新モデルでは脅迫的表現は無効化されている。

---

## KE-008: 過剰構造化の回避

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance)
- **scope**: プロンプトの構造化レベルを決定するとき
- **action**: 軽量ヒント2件を上限とする。チェックリスト統合、厳格カテゴリ化は避ける。カテゴリ分解レベルに留める。
- **rationale**: 構造化の量と性能は逆U字の関係にある。過剰構造化は一貫して逆効果であり、チェックリスト統合で-1.75pt、厳格カテゴリで-4.5ptの低下が確認されている。軽量ヒント2件が最適閾値、3件以上で逆効果。

---

## KE-009: 推論精度優先時のNL-to-Formatアプローチ

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance)
- **scope**: 推論の質が最優先で、かつ構造化出力も必要な場合
- **action**: 自然言語で回答させ、後からフォーマット変換するNL-to-Formatアプローチを採用する。
- **rationale**: フォーマット制約が厳しいほど推論能力の低下が大きい。推論精度最優先なら、自然言語で回答させ後からフォーマット変換する方が有効。

---

## KE-010: Structured Outputsによるスキーマ準拠保証

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance)
- **scope**: JSON出力の信頼性が要求される自動化タスク
- **action**: Structured Outputsを使用してスキーマ準拠を強制する。重要なプロンプトには自己チェックブロックを付加して出力フォーマット準拠を検証させる。
- **rationale**: プロンプトエンジニアリング単体では35.9%の信頼性に留まるが、Structured Outputsで100%を達成。スキーマドリフトが壊れた自動化の最大原因であり、スキーマ強制で防止可能。

---

## KE-011: Self-Consistencyの優先適用

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance)
- **scope**: 算術推論・常識推論タスク
- **action**: Self-Consistency（複数推論パスから最頻回答を選択）を適用する。
- **rationale**: 算術・常識推論で4倍以上の効率改善が確認されている。

---

## KE-012: Adaptive Thinkingの優先使用（Claude 4.6）

- **use-when**: Claude 4.x固有の機能・制約に対応してプロンプトを調整するとき
- **scope**: Claude 4.6使用時
- **action**: `thinking: {type: "adaptive"}` でAdaptive Thinkingを使用する。Extended Thinkingより優先する。
- **rationale**: クエリ複雑度に応じた動的思考により、Extended Thinkingより一貫して高性能。

---

## KE-013: ディストラクター効果の活用

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance)
- **scope**: 推論強化手法を使用する場合
- **action**: もっともらしい誤答選択肢を明示的に含める。
- **rationale**: 推論強化はキャリブレーションを悪化させる（84.3%のシナリオで過信）。ディストラクター効果により精度最大460%改善、キャリブレーション誤差90%減少が確認されている。

---

## KE-014: Claude 4.xの明示的指示要求

- **use-when**: Claude 4.x固有の機能・制約に対応してプロンプトを調整するとき
- **scope**: Claude 4.xシリーズ使用時
- **action**: 指示を文字通り解釈されることを前提に、"above and beyond"な動作を望む場合は明示的に要求する。
- **rationale**: Claude 4.xは指示を文字通りに解釈する。以前のモデルは曖昧な指示から意図を推測して拡張したが、現行モデルは要求されたことだけを正確に実行する。

---

## KE-015: 理由の提供による汎化促進

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance)
- **scope**: 制約や禁止事項を指示する場合
- **action**: 「〜するな」ではなく「〜のため、〜を〜せよ」と理由付きで指示する。
- **rationale**: 理由を述べることでモデルが汎化する。例:「省略記号を使うな」ではなく「テキスト読み上げエンジンが処理できないため、省略記号を使用しない」。

---

## KE-016: Claude 4.6のPrefill廃止対応

- **use-when**: Claude 4.x固有の機能・制約に対応してプロンプトを調整するとき
- **scope**: Claude 4.6使用時
- **action**: Prefillの代わりに、出力フォーマット制御にはStructured Outputsを、前文排除には"Respond directly without preamble"の直接指示を使用する。
- **rationale**: Claude 4.6では最後のアシスタントターンのプリフィルが非サポートになった。代替手法への移行が必要。

---

## KE-017: 言語一貫性の厳守

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance)
- **scope**: プロンプトの言語選択時
- **action**: 完全英語 or 完全日本語のどちらかに統一する。混合を避ける。
- **rationale**: 混合は検出パターンシフトと安定性悪化を引き起こす。
