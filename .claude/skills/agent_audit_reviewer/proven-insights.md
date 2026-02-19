<!-- Auto-updated by agent_audit_reviewer. Last updated: 2026-02-18, Agents: 1, Rounds: 3 -->

# Proven Insights

agent_audit_reviewer のエージェント最適化から抽出したエラー駆動型の知見。

---

## 1. Error→Fix Patterns
<!-- Max 10 entries. Merge similar entries if exceeded. -->

| Error Category | Fix Pattern | Effect | Stability | Source |
|---------------|-------------|--------|-----------|--------|

## 2. Generally Effective Patterns
<!-- Max 8 entries. Merge similar entries if exceeded. -->

| Pattern | Effect | Stability | Source |
|---------|--------|-----------|--------|

## 3. Anti-Patterns
<!-- Max 8 entries. Remove weakest evidence entry if exceeded. -->

| Pattern | Effect | Source |
|---------|--------|--------|
| 特定セクションの評価基準を深化（チェックリスト再構成または文言追加）すると、変更規模によらず注意資源の配分が変化し、無関係カテゴリで回帰を引き起こす（注意分散アンチパターン）。再構成時: -1.425pt・入力検証(-0.20)の回帰。文言追加のみでも: -0.775pt・入力検証(-0.20)・インフラ(-0.15)の回帰 | -0.775〜-1.425pt, 回帰: 入力検証・攻撃防御(-0.20), インフラ・依存関係・監査(-0.15) | agents/security-design-reviewer:R2, agents/security-design-reviewer:R3 |
