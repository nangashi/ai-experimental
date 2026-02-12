# Answer Key: alpha SA (Scope Alignment)

5 planted problems in api-design-reviewer.

| ID | Type | Section | Problematic Text or Absence | Why It's a Problem |
|----|------|---------|----------------------------|-------------------|
| S1 | missing-outofscope | 全体 | Out of Scope セクションが存在しない | レビュー対象外の領域が不明;他エージェントとの境界が定義されていない |
| S2 | scope-creep | §7 | "Integration Testing Design" セクション全体 | APIデザインレビューのスコープにテスト設計は含まれない;テストレビューは別エージェントの担当 |
| S3 | boundary-ambiguity | §3 | "Authentication & Security" セクション | セキュリティレビューアーとの境界が不明;認証設計はセキュリティドメインと重複する |
| S4 | scope-exceed | §4 | "Performance & Scalability" セクション | スコープ定義は "API endpoint design, request/response formats, and integration patterns" だが、性能・スケーラビリティはスコープ外 |
| S5 | missing-crossref | 全体 | 他エージェントへの参照が一切ない | 関連ドメイン(セキュリティ、性能、テスト)を誰が担当するかの記載がない |
