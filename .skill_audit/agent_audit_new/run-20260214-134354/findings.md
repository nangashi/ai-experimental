## 重大な問題

なし

## 改善提案

### I-1: テンプレート内の未定義変数 [stability]
- 対象: templates/collect-findings.md:7, 12, 43行目
- 内容: テンプレート内で `{agent_name}` を参照しているが、SKILL.md の Phase 2 Step 1 のパス変数リスト（190-191行目）では `{agent_name}` が定義されていない
- 推奨: SKILL.md 191行目の後に「- `{agent_name}`: {実際の agent_name}」を追加する
- impact: medium, effort: low

---
注: 改善提案を 10 件省略しました（合計 11 件中上位 1 件を表示）。省略された項目は次回実行で検出されます。
