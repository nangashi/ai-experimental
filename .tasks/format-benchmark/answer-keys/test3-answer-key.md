# Answer Key: test3-api-design-reviewer

## 埋め込み問題一覧

### Surface (S) — チェックリストで検出可能

| ID | 問題 | 該当箇所 | 種別 |
|----|------|---------|------|
| S1 | 最小限のロール定義 | "You are an API design reviewer." — 専門性・コンテキストの記述なし | Weak Role |
| S2 | 曖昧なseverity定義 | "Critical: Breaking issues" — 1語の定義で閾値が不明 | Vague Severity |
| S3 | 曖昧表現の多用 | Criteria 3: "suitable for their intended purpose"; Criteria 4/6: "properly"; Criteria 8: "appropriately" | Vague Expression |

### Deep (D) — 構造的分析で検出可能

| ID | 問題 | 該当箇所 | 種別 |
|----|------|---------|------|
| D1 | スコープ境界の曖昧さ | Criteria 6 "Authentication and Authorization Design" はセキュリティレビューとの境界が不明確 | Scope Overlap |
| D2 | 限定的適用可能性 | Criteria 11 "HATEOAS" は特定のアーキテクチャスタイルに依存。非HATEOAS APIへの適用は不適切 | Narrow Applicability |
| D3 | 実行不可能基準 | Criteria 12 "Real-time Data Consistency Verification" — レビュー中にバックエンドDBへのリアルタイムアクセスは不可能 | INFEASIBLE |

### Latent (L) — 敵対的思考で検出可能

| ID | 問題 | 該当箇所 | 種別 |
|----|------|---------|------|
| L1 | トートロジー | Criteria 9: "Evaluate whether the API documentation is complete by checking all aspects of the documentation thoroughly" + "meets professional standards for API documentation excellence" — 具体的チェック項目なしにタイトルを言い換え | Tautology |
| L2 | 循環定義 | Criteria 1: "The API should be designed in a RESTful manner following industry standards" — タイトル "RESTful Convention Adherence" の言い換え | Circular Definition |
| L3 | トートロジー尾部 | Criteria 4: "The API should handle errors properly" — 前の具体的基準の後に加えられた無意味な総括文 | Tautological Tail |
| L4 | 能動的検出姿勢の欠如 | Evaluation Stance や "actively identify" の記述がなく、記述されたものしか評価しない受動的設計 | Missing Active Stance |

## 合計: 10問題 (S:3, D:3, L:4)
