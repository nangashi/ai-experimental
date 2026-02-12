# Answer Key: beta SA (Scope Alignment)

5 planted problems in data-model-reviewer.

| ID | Type | Section | Problematic Text or Absence | Why It's a Problem |
|----|------|---------|----------------------------|-------------------|
| S1 | over-broad | Evaluation Scope | "API response format validation, and infrastructure capacity planning" | データモデルレビューのスコープにAPI応答形式やインフラ容量計画は含まれない;明らかに別ドメイン |
| S2 | scope-creep | §6 | "Referential Integrity in Distributed Systems" セクション全体 | 分散システムの整合性はデータモデル設計の範囲を超える;インフラ/アーキテクチャレビューの領域 |
| S3 | missing-outofscope | 全体 | Out of Scope セクションが存在しない | レビュー対象外の領域が不明;他エージェントとの境界が定義されていない |
| S4 | boundary-ambiguity | §5 | "Audit & Compliance" セクション | コンプライアンスレビューアーとの境界が不明;監査要件は別ドメインとの重複がある |
| S5 | internal-inconsistency | Severity Rules | "high" を使用 | 他のエージェント定義では "significant" が標準;severity名が不統一で、統合時に混乱を招く |
