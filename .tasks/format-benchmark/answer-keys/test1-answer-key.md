# Answer Key: test1-code-quality-reviewer

## 埋め込み問題一覧

### Surface (S) — チェックリストで検出可能

| ID | 問題 | 該当箇所 | 種別 |
|----|------|---------|------|
| S1 | 曖昧表現の多用 | Criteria 1: "appropriate", "as needed"; Criteria 2: "appropriate length", "reasonable", "suitable"; Criteria 3: "adequate", "appropriately", "sufficient" | Vague Expression |
| S2 | 基準の重複 | Criteria 1 "Code Readability" と Criteria 6 "Code Readability Assessment" が >70% 意味的重複 | Duplication |
| S3 | 循環的 severity 定義 | "High: Issues that significantly impact code quality" — 「品質」を「品質の問題」で定義 | Circular Severity |

### Deep (D) — 構造的分析で検出可能

| ID | 問題 | 該当箇所 | 種別 |
|----|------|---------|------|
| D1 | スコープ外基準 | Criteria 8 "Dependency Management" の「unused imports, circular dependencies」はコード構造の問題で、code quality reviewerの中核スコープからやや逸脱 | Scope Deviation |
| D2 | スコープ外基準 | Criteria 9 "Test Coverage Alignment" はテスト戦略の領域で、readability/maintainability/best practicesの範囲を超える | Scope Deviation |
| D3 | 低コスト効率基準 | Criteria 4 "Code Duplication Detection" はコードベース全体の走査が必要で高コスト | Cost-Effectiveness |

### Latent (L) — 敵対的思考で検出可能

| ID | 問題 | 該当箇所 | 種別 |
|----|------|---------|------|
| L1 | トートロジー | Criteria 1: "Evaluate whether the code is readable and understandable" — タイトルの言い換えに過ぎず操作的ガイダンスなし | Tautology |
| L2 | 循環定義 | Severity "High": 「code qualityに重大な影響」— code quality reviewerのseverityをcode qualityで定義する循環 | Circular Definition |
| L3 | 擬似精密表現 | Criteria 9: "industry-standard benchmarks" — 精密に聞こえるが基準未定義 | Pseudo-Precision |
| L4 | 偽装された重複 | Criteria 6はCriteria 1のリフレーミング（formatフォーカス vs 一般的可読性）。表面上は異なるが実質重複 | Disguised Duplication |

## 合計: 10問題 (S:3, D:3, L:4)
