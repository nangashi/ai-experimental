## コンフリクト

### CONF-1: SKILL.md:224-240 - Phase 2 Step 1 prompt の外部化
- 側A: [efficiency] 17行の inline prompt をテンプレート外部化すべき（7行超のため原則違反）
- 側B: [architecture] 31行の直接 prompt をテンプレート外部化すべき（「Read template + follow instructions」パターン不使用）
- 対象findings: C-6, I-1

### CONF-2: Phase 2 検証ステップの外部化
- 側A: [efficiency] 検証ステップ（L311-323, 15行）を `templates/validate-agent-structure.md` に外部化すべき（行数削減）
- 側B: [architecture] 検証ステップの構造検証が最小限で、必須セクション検証・破損検出が不足
- 対象findings: C-5, I-2, I-6
