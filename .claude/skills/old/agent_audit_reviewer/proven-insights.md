<!-- Auto-updated by agent_audit_reviewer. Last updated: 2026-02-16, Agents: 1, Rounds: 10 -->

# Proven Insights

agent_audit_reviewer のエージェント最適化から抽出したエラー駆動型の知見。各ラウンドのエラー分析→修正の対応パターンを蓄積する。

---

## 1. Error→Fix Patterns
<!-- Max 10 entries. Merge similar entries if exceeded. -->

| Error Category | Fix Pattern | Effect | Stability | Source |
|---------------|-------------|--------|-----------|--------|
| 認可設計の部分/未検出 | APIエンドポイントごとの具体的な認可チェック例を明示的に列挙（メッセージ送信時のルームメンバー確認、ファイルアクセス権限、管理者API認可、メッセージ履歴アクセス制御） | +2.7pt | SD=0.5 | agents/security-design-reviewer:R1 |

## 2. Generally Effective Patterns
<!-- Max 8 entries. Merge similar entries if exceeded. -->

| Pattern | Effect | Stability | Source |
|---------|--------|-----------|--------|
| 具体的APIエンドポイント例の明示的列挙 | +2.7pt | SD=0.5 | agents/security-design-reviewer:R1 |

## 3. Anti-Patterns
<!-- Max 8 entries. Remove weakest evidence entry if exceeded. -->

| Pattern | Effect | Source |
|---------|--------|--------|
| 特定カテゴリの詳細化により他カテゴリの網羅性が犠牲になる（認可設計への焦点強化→認証設計/データ保護の検出弱化、認証設計詳細化→認可設計/インフラ/データ保護の検出低下、インフラ分析強化→認証設計/攻撃防御の検出低下、認証設計詳細化→脅威モデリング/データ保護検出低下+安定性悪化、インフラ詳細化→脅威モデリング/データ保護/CSRF検出低下、構造圧縮＋認証詳細化→入力検証/データ保護の未検出化、重大度優先＋脅威モデリング強化→WebSocket認証未検出化＋ボーナス獲得激減、データ保護・脅威モデリング・インフラ強化→入力検証・攻撃防御への注意分散、包括的カバレッジ強化→CSRF対策とCORS設定の独立性低下、重大度優先→中軽微問題への注意低下＋ボーナス獲得皆無、セクション分割により包括カバレッジ消失） | -1.3pt〜-4.7pt | agents/security-design-reviewer:R1,R2,R3,R4,R5,R6,R7,R8,R9,R10 |
