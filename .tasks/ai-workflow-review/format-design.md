# レビュー観点フォーマット設計

## 既存instructions形式との違い

既存の `.claude/instructions/` は「作業中に参照する行動指針」であり、action（何をすべきか）が主軸。
本レビュー観点は「既存の設計・実装を評価するチェックリスト」であり、check（YES/NO判定）が主軸。

この用途の違いに基づき、レビュー検出精度を最大化するフォーマットを設計した。

## フォーマット選定根拠

| 設計判断 | 採用理由 | エビデンス |
|----------|----------|-----------|
| YES/NO二値チェック形式を主軸に | Likert尺度や自由記述より一致率+5.8pp、判定精度+17.7pp向上 | TICK (arXiv:2410.03608), RRD (arXiv:2602.05125) |
| 1項目1チェック（atomic） | 複合条件（AかつB）は判定精度を低下させる | RRD (arXiv:2602.05125) |
| 簡潔なrationale（1-2文+定量値） | CoTスキャフォールドとして+3.7-13.4%精度向上。ただし3文以上は過剰構造化（-1.75pt） | G-Eval (EMNLP 2023), prompt-engineering-findings.md |
| improvement（期待改善）の明記 | 重要度キャリブレーションとして機能し、検出漏れを低減 | G-Eval, Prometheus (ICLR 2024) |
| severity明示（3段階） | 未分類だとLLMが均一扱いし、人間の判断と不整合 | LLM-Rubric (ACL 2024) |
| カテゴリ別分解 | 最も安定した分解方式（SD=0.0） | prompt-engineering-findings.md |
| 例示なし | レビュー・検出タスクではゼロショットが優位。2例超でテンプレートバイアス発生 | prompt-engineering-findings.md |

## フィールド定義

```
## [Category]

### [ID]: [Title]

- **check**: YES/NOで判定可能な質問形式。1つの観点のみを問う
- **scope**: この観点が適用される実装・設計の状況
- **action**: checkがNOの場合に取るべき対応
- **rationale**: なぜこの対応が有効か（定量エビデンス付き、1-2文）
- **improvement**: 対応による期待改善（可能な限り定量的）
- **severity**: critical | major | minor
```

### フィールド順序の意図

1. **check** を最初に置くことで、レビュアーが判定対象を即座に把握
2. **scope** で適用可否を判断（該当しない項目をスキップ）
3. **action** で対応方法を確認（checkがNOの場合のみ参照）
4. **rationale** + **improvement** で優先度判断の材料を提供
5. **severity** で最終的な重要度キャリブレーション

## 参考文献

- TICK: Targeted Instruct-evaluation with ChecKlists (Li et al., 2024) - arXiv:2410.03608
- RRD: Recursive Rubric Decomposition (2025) - arXiv:2602.05125
- CheckEval: Checklist-based Evaluation (Lee et al., EMNLP 2025) - arXiv:2403.18771
- G-Eval (Liu et al., EMNLP 2023) - arXiv:2303.16634
- LLM-Rubric: Multidimensional Calibrated Evaluation (Microsoft, ACL 2024)
- Prometheus (Kim et al., ICLR 2024) - arXiv:2310.08491
- RULERS: Locked Executable Rubrics (2026) - arXiv:2601.08654
- Rubric Is All You Need (Pappireddi et al., ICER 2025)
- Position Bias in Rubric-Based Evaluation (2025) - arXiv:2602.02219
