# Answer Key: test2-data-pipeline-auditor

## 埋め込み問題一覧

### Surface (S) — チェックリストで検出可能

| ID | 問題 | 該当箇所 | 種別 |
|----|------|---------|------|
| S1 | 曖昧表現 | Criteria 9: "appropriately", "applicable...frameworks appropriately" | Vague Expression |
| S2 | スコープ過大 | "all aspects of data pipeline quality" — 9基準でingestionからgovernanceまで網羅は過大 | Scope Too Broad |

### Deep (D) — 構造的分析で検出可能

| ID | 問題 | 該当箇所 | 種別 |
|----|------|---------|------|
| D1 | 実行不可能基準 | Criteria 7: "Set up alerts", "Implement dashboards" — 評価ではなく実装アクション。静的レビューエージェントの機能を逸脱 | INFEASIBLE (Action) |
| D2 | 実行不可能基準 | Criteria 8: "full reconciliation checks...on every pipeline run" — ランタイム要件であり静的レビューで実行不可能 | INFEASIBLE (Runtime) |
| D3 | 低コスト効率基準 | Criteria 3: "every single record" のトレースは静的レビューでは実行不可能 | Cost-Effectiveness / INFEASIBLE |

### Latent (L) — 敵対的思考で検出可能

| ID | 問題 | 該当箇所 | 種別 |
|----|------|---------|------|
| L1 | 擬似精密表現 | Criteria 2: "statistical verification with 99.9% confidence intervals" — 静的コード/設計レビューでは不可能な精度要求 | Pseudo-Precision |
| L2 | 評価/実装の境界違反 | Criteria 7: "Set up alerts" "Implement dashboards" — auditエージェントなのに実装を指示。評価と実装の役割混同 | Role Confusion |
| L3 | 擬似精密表現 | Criteria 8: "0.001%" — 精密に見えるが静的レビューで検証不可能な閾値 | Pseudo-Precision |
| L4 | スケール不可能要件 | Criteria 3: "every single record" — 全レコードのリネージ保持は大規模パイプラインで非現実的な要件を静的に検証することはさらに非現実的 | Infeasible Scale |

## 合計: 9問題 (S:2, D:3, L:4)
