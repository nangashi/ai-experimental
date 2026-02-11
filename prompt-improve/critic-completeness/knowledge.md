# Agent Optimize Knowledge: critic-completeness

## 対象エージェント
- **エージェント名**: critic-completeness
- **エージェントパス**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/reviewer_create/templates/critic-completeness.md
- **エージェント目的**: 観点定義の網羅性と盲点検出能力を評価する批評エージェント。特に「存在しないものを検出できるか」（未考慮事項の検出能力）の評価が最も重要な責務。
- **累計ラウンド数**: 1
- **初期スコア**: 8.85 (Round 001 baseline)

## パフォーマンス改善の要素

### 効果が確認された構造変化
| 変化 | 効果 (pt) | 安定性 (SD) | 確認ラウンド | 備考 |
|------|-----------|-------------|-------------|------|
| タスクチェックリスト (C1a) | +1.15 | 0.00 | Round 001 | "まず〜、次に〜"の段階的実行指示。Perfect 10.00達成。特に中難易度シナリオで+2.09pt効果 |

### 効果が限定的/逆効果だった構造変化
| 変化 | 効果 (pt) | 安定性 (SD) | 確認ラウンド | 備考 |
|------|-----------|-------------|-------------|------|
| Few-shot examples (S1a) | -1.07 | 0.24 | Round 001 | 特に高難易度シナリオで-1.85pt。認知オーバーヘッドによる柔軟性低下が原因と推測 |

### バリエーションステータス
| Variation ID | Status | Round | Effect (pt) | Notes |
|-------------|--------|-------|-------------|-------|
| S1a | INEFFECTIVE | Round 001 | -1.07 | 基本 — 異なる難易度/種類の入出力例を1-2個追加 |
| S1b | UNTESTED | - | - | ドメイン特化 — 対象エージェントの典型的タスクに特化した例 |
| S1c | UNTESTED | - | - | 敵対的 — 判断が難しいエッジケースの処理例 |
| S1d | UNTESTED | - | - | 否定例 — やるべきでないこと(失敗例)の明示 |
| S2a | UNTESTED | - | - | 基本品質基準 — 出力品質の5段階または3段階基準 |
| S2b | UNTESTED | - | - | チェックリスト型 — 出力に含めるべき要素の明示的リスト |
| S2c | UNTESTED | - | - | 比較基準 — 良い出力と悪い出力の特徴リスト |
| S3a | UNTESTED | - | - | セクション名のみ（テンプレート削除） |
| S3b | UNTESTED | - | - | 最小自由記述（セクション構造なし） |
| S3c | UNTESTED | - | - | テーブル中心（表形式で統一） |
| S4a | UNTESTED | - | - | 1行要約化 — 各項目の説明を核心1行に削減 |
| S4b | UNTESTED | - | - | 階層簡略化 — 見出し維持+内容フラット化 |
| S5a | UNTESTED | - | - | タスクチェックリスト — 実行すべきことのリスト |
| S5b | UNTESTED | - | - | アンチパターンリスト — 避けるべきことのリスト |
| S5c | UNTESTED | - | - | 欠落検出 — 「存在すべきだが欠けているもの」の確認指示 |
| C1a | EFFECTIVE | Round 001 | +1.15 | 基本段階的分析 — 「まず〜、次に〜」の手順指示 |
| C1b | UNTESTED | - | - | 自問フレームワーク — 各ステップで自問リスト付与 |
| C1c | UNTESTED | - | - | マルチパス — 1回目:全体把握、2回目:詳細分析 |
| C2a | UNTESTED | - | - | 専門家ペルソナ — 分野の権威としてのロール設定 |
| C2b | UNTESTED | - | - | メンター視点 — 教育的観点で丁寧に分析 |
| C2c | UNTESTED | - | - | 二重役割 — 分析者+検証者の両面 |
| C3a | UNTESTED | - | - | 重要度優先 — 重要な要素から処理する指示 |
| C3b | UNTESTED | - | - | リスクベース — 発生確率×影響度で順序付け |
| C3c | UNTESTED | - | - | カテゴリ→重要度 — カテゴリ別にグループ化してから重要度順 |
| C4a | UNTESTED | - | - | 完了チェック — 「出力前に以下を確認せよ」のリスト |
| C4b | UNTESTED | - | - | 反証思考 — 「自分の結論に対する反論を考えよ」 |
| C4c | UNTESTED | - | - | 品質ゲート — 各セクション完了時の品質確認ステップ |
| N1a | UNTESTED | - | - | 業界標準ベース — 該当分野の標準知識を追加 |
| N1b | UNTESTED | - | - | アンチパターン集 — 典型的な失敗パターンリスト |
| N1c | UNTESTED | - | - | 隣接領域の知識 — 関連分野からの知見を追加 |
| N2a | UNTESTED | - | - | 全文英語 — プロンプト全体を英語に変換 |
| N2b | UNTESTED | - | - | 混合言語 — 技術用語は英語、説明は日本語 |
| N2c | UNTESTED | - | - | 全文日本語 — 対照群 |
| N3a | UNTESTED | - | - | 最小化 — 全体を50%程度に圧縮 |
| N3b | UNTESTED | - | - | 拡張 — 判断基準や理由を50%程度増量 |
| N3c | UNTESTED | - | - | 選択的最適化 — 低価値セクションのみ削除 |
| N4a | UNTESTED | - | - | 明示的制約 — 出力の長さ・形式・スコープの明示 |
| N4b | UNTESTED | - | - | ネガティブ制約 — 「〜してはいけない」の明示 |
| N4c | UNTESTED | - | - | スコープ限定 — 「〜のみに集中せよ」の明示 |
| M1a | UNTESTED | - | - | 事前分析+本実行 — 「まず理解し、次に実行せよ」の2段階 |
| M1b | UNTESTED | - | - | 実行と出力の分離 — 分析フェーズと出力整形フェーズを分離 |
| M2a | UNTESTED | - | - | 最低出力要件 — 「最低N項目を含めること」 |
| M2b | UNTESTED | - | - | 制約緩和 — 不要な制約の削除（自由度向上） |
| M2c | UNTESTED | - | - | 確信度注釈 — 各出力に確信度(高/中/低)を付与させる |
| M3a | UNTESTED | - | - | 重要情報の先頭配置 — プロンプトの冒頭に最重要指示 |
| M3b | UNTESTED | - | - | 繰り返し強調 — 重要指示を冒頭と末尾の両方に配置 |
| M3c | UNTESTED | - | - | 階層的情報配置 — 概要→詳細→補足の順序で構成 |

## テストセット履歴

| ラウンド | テーマ/シナリオ | 主要品質次元 |
|---------|---------------|-------------|
| Round 001 | 8 scenarios (T01-T08) evaluating completeness critique capability | Scope coverage analysis, missing element detection, problem bank quality evaluation, edge case identification |

## 最新ラウンドサマリ

**Round 001**:
- **Variants**: v001-baseline (8.85±0.40), v001-fewshot (7.78±0.24), v001-tasklist (10.00±0.00)
- **Recommended**: v001-tasklist (C1a)
- **Key Insights**: Task checklist achieved perfect scores across all 8 scenarios with zero variance. Few-shot examples regressed -1.07 pt, particularly on hard scenarios (-1.85 pt). Structured phasing ensures comprehensive criterion coverage.
- **Next Actions**: Test C1a+C4a combination, consider harder scenarios to avoid ceiling effects, measure efficiency metrics.

## 改善のための考慮事項

1. **段階的実行チェックリストは網羅性を高める** — 「Phase 1: Initial Analysis, Phase 2: Scope Coverage, Phase 3: Missing Element Detection, Phase 4: Problem Bank Quality」形式の段階的指示により、評価基準の漏れを防ぎ、全シナリオで満点達成 (根拠: Round 001, C1a, 効果+1.15pt, SD=0.00)

2. **Few-shot examplesは複雑タスクで逆効果** — 1-2個の入出力例追加は特に高難易度シナリオで-1.85ptの性能低下。例による思考の固定化や認知負荷が原因と推測 (根拠: Round 001, S1a, 効果-1.07pt)

3. **構造化ガイダンスは再現性を向上させる** — チェックリスト方式により実行の曖昧性が減少し、run間の分散がゼロに (根拠: Round 001, C1a, SD=0.00 vs baseline SD=0.40)

4. **中難易度シナリオで構造化の効果が最大化** — 易しいタスクでは差が小さい(+0.20pt)が、中難易度タスクでは+2.09pt、複雑な分析が必要なタスクほど段階的アプローチが効果的 (根拠: Round 001, C1a, medium scenarios analysis)

5. **量的評価基準にはチェックリストが有効** — 「count problems vs guideline」のような定量的評価項目で特に効果。明示的な計数指示により見落としを防止 (根拠: Round 001, T08 +2.77pt with C1a)
