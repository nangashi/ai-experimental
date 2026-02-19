# Scoring Report: v006-baseline (Round 006)

## Execution Conditions
- **Perspective**: security
- **Target**: design
- **Embedded Problems**: 10
- **Scoring Date**: 2026-02-10

---

## Run 1 Scoring

### Problem Detection Matrix

| Problem ID | Category | Severity | Detection | Score | Notes |
|------------|----------|----------|-----------|-------|-------|
| P01 | 認証・認可設計 | 重大 | ○ | 1.0 | Section 1.1でJWT localStorage + XSS脆弱性を完全に指摘。HttpOnly Cookie推奨あり |
| P02 | インフラ・依存関係 | 重大 | ○ | 1.0 | Section 1.3でStripe Webhook署名検証欠如を指摘。`stripe.webhooks.constructEvent()`に明示的言及 |
| P03 | 入力検証設計 | 重大 | △ | 0.5 | Section 1.4でファイルタイプ制限の欠如を指摘しているが、Content-Type偽装やマジックバイト検証への具体的言及なし |
| P04 | 脅威モデリング | 中 | ○ | 1.0 | Section 2.1でレート制限の具体的方針欠如を指摘。ログインエンドポイントのブルートフォース対策に明示的言及 |
| P05 | 認証・認可設計 | 中 | × | 0.0 | 決済処理の冪等性について言及なし（Section 1.7で一般的なIdempotency-Key実装は提案しているが、決済固有の問題として指摘していない） |
| P06 | 認証・認可設計 | 中 | × | 0.0 | パスワードリセット・メール検証フローの欠如について言及なし |
| P07 | データ保護 | 中 | × | 0.0 | 動画ストリーミングURLの署名付きURL方針欠如について言及なし（Section 2.9でライブストリーミングの署名付きURLは提案しているが、正解キーのP07は録画動画ストリーミングURLの問題であり、対象が異なる） |
| P08 | 認証・認可設計 | 中 | × | 0.0 | 課題評価時の教師の権限検証（リソースベース認可）について言及なし |
| P09 | 情報漏洩防止 | 軽微 | ○ | 1.0 | Section 2.10でエラーメッセージの情報漏洩リスクを指摘。DBスキーマ・内部パスの露出を具体的に言及 |
| P10 | 情報漏洩防止 | 軽微 | ○ | 1.0 | Section 1.5で認可失敗ログや機密操作の監査ログ欠如を指摘。Who/What/When形式に言及 |

**Detection Score: 5.5 / 10**

---

### Bonus Analysis

| ID | Description | Judgment | Score | Notes |
|----|-------------|----------|-------|-------|
| B01 | JWT有効期限（24h）が長すぎる | ○ ボーナス | +0.5 | Section 1.1で24時間が過剰と明示的に指摘し、15分+リフレッシュトークン推奨 |
| B02 | 入力値の型・形式検証欠如 | ○ ボーナス | +0.5 | Section 1.5で包括的な入力検証ポリシー欠如を指摘し、Joi/Zodスキーマ例を提示 |
| B03 | TLSバージョン最小値未記載 | × | 0 | TLS 1.0/1.1の無効化について言及なし |
| B04 | 依存ライブラリ脆弱性スキャン欠如 | ○ ボーナス | +0.5 | Section 2.8でnpm audit/Snyk統合やパッチSLAを詳細に提案 |
| B05 | アカウントロックアウト機能欠如 | ○ ボーナス | +0.5 | Section 1.3で5回失敗後30分ロック実装を明示的に推奨 |
| B06 | S3バケットアクセス制御設計欠如 | △ | 0 | Section 2.9でS3暗号化は言及しているが、バケットポリシーやIAMロールの具体的設計には言及不足 |
| B07 | CSRF対策の記載/判断根拠欠如 | ○ ボーナス | +0.5 | Section 1.2およびSection 2.1でCSRF保護の必要性を明示的に指摘。Double Submit Cookie提案あり |
| B08 | DB保存時暗号化範囲不明確 | ○ ボーナス | +0.5 | Section 2.9でRDS暗号化・S3 SSE-KMS・アプリ層暗号化を包括的に提案 |

**Bonus Count: 6件**
**Bonus Score: +3.0**

---

### Penalty Analysis

| ID | Description | Judgment | Score | Notes |
|----|-------------|----------|-------|-------|
| - | なし | - | 0 | スコープ外指摘や事実誤認なし |

**Penalty Count: 0件**
**Penalty Score: 0**

---

### Run 1 Total Score

```
Run1 Score = 5.5 (detection) + 3.0 (bonus) - 0 (penalty) = 8.5
```

---

## Run 2 Scoring

### Problem Detection Matrix

| Problem ID | Category | Severity | Detection | Score | Notes |
|------------|----------|----------|----------|-------|-------|
| P01 | 認証・認可設計 | 重大 | ○ | 1.0 | Section 1.1でJWT localStorage + XSS脆弱性を完全に指摘。HttpOnly Cookie推奨あり |
| P02 | インフラ・依存関係 | 重大 | ○ | 1.0 | Section 2.2でStripe Webhook署名検証欠如を指摘。`stripe.webhooks.constructEvent()`に明示的言及 |
| P03 | 入力検証設計 | 重大 | △ | 0.5 | Section 1.4でファイルタイプ制限の欠如を指摘しているが、Content-Type偽装やマジックバイト検証への具体的言及なし |
| P04 | 脅威モデリング | 中 | ○ | 1.0 | Section 1.3でレート制限の具体的方針欠如を指摘。ログインエンドポイントのブルートフォース対策に明示的言及 |
| P05 | 認証・認可設計 | 中 | ○ | 1.0 | Section 1.7で決済処理の冪等性欠如を明示的に指摘。Stripe Idempotency-Keyに言及 |
| P06 | 認証・認可設計 | 中 | × | 0.0 | パスワードリセット・メール検証フローの欠如について言及なし |
| P07 | データ保護 | 中 | × | 0.0 | 動画ストリーミングURLの署名付きURL方針欠如について言及なし（Section 2.10でライブストリーミングの署名付きURLは提案しているが、P07は録画動画ストリーミングURLの問題） |
| P08 | 認証・認可設計 | 中 | × | 0.0 | 課題評価時の教師の権限検証（リソースベース認可）について言及なし |
| P09 | 情報漏洩防止 | 軽微 | ○ | 1.0 | Section 2.10でエラーメッセージの情報漏洩リスクを指摘。DBスキーマ・内部パスの露出を具体的に言及 |
| P10 | 情報漏洩防止 | 軽微 | ○ | 1.0 | Section 1.6で認可失敗ログや機密操作の監査ログ欠如を指摘。Who/What/When形式に言及 |

**Detection Score: 6.5 / 10**

---

### Bonus Analysis

| ID | Description | Judgment | Score | Notes |
|----|-------------|----------|-------|-------|
| B01 | JWT有効期限（24h）が長すぎる | ○ ボーナス | +0.5 | Section 1.1で24時間が過剰と明示的に指摘し、15分+リフレッシュトークン推奨 |
| B02 | 入力値の型・形式検証欠如 | ○ ボーナス | +0.5 | Section 1.5で包括的な入力検証ポリシー欠如を指摘し、Joi/Zodスキーマ例を提示 |
| B03 | TLSバージョン最小値未記載 | × | 0 | TLS 1.0/1.1の無効化について言及なし |
| B04 | 依存ライブラリ脆弱性スキャン欠如 | ○ ボーナス | +0.5 | Section 2.8でnpm audit/Snyk統合やパッチSLAを詳細に提案 |
| B05 | アカウントロックアウト機能欠如 | ○ ボーナス | +0.5 | Section 1.3で5回失敗後30分ロック実装を明示的に推奨 |
| B06 | S3バケットアクセス制御設計欠如 | △ | 0 | Section 2.9でS3暗号化は言及しているが、バケットポリシーやIAMロールの具体的設計には言及不足 |
| B07 | CSRF対策の記載/判断根拠欠如 | ○ ボーナス | +0.5 | Section 2.1でCSRF保護の必要性を明示的に指摘。Double Submit Cookie提案あり |
| B08 | DB保存時暗号化範囲不明確 | ○ ボーナス | +0.5 | Section 2.9でRDS暗号化・S3 SSE-KMS・アプリ層暗号化を包括的に提案 |

**Bonus Count: 6件**
**Bonus Score: +3.0**

---

### Penalty Analysis

| ID | Description | Judgment | Score | Notes |
|----|-------------|----------|-------|-------|
| - | なし | - | 0 | スコープ外指摘や事実誤認なし |

**Penalty Count: 0件**
**Penalty Score: 0**

---

### Run 2 Total Score

```
Run2 Score = 6.5 (detection) + 3.0 (bonus) - 0 (penalty) = 9.5
```

---

## Baseline Summary

| Run | Detection Score | Bonus | Penalty | Total Score |
|-----|----------------|-------|---------|-------------|
| Run1 | 5.5 | +3.0 | -0 | 8.5 |
| Run2 | 6.5 | +3.0 | -0 | 9.5 |
| **Mean** | **6.0** | **+3.0** | **-0** | **9.0** |
| **SD** | **0.5** | **0** | **0** | **0.5** |

---

## Key Differences Between Runs

### Run1 vs Run2 Detection Differences

**P05 (決済処理の冪等性保証欠如):**
- Run1: Section 1.7で一般的なIdempotency-Key実装は提案しているが、決済APIの冪等性欠如として明示的に指摘していない → ×（未検出）
- Run2: Section 1.7で「決済セッション作成APIに冪等性キーの設計が記載されていない」と明示的に指摘 → ○（検出）

この1問の差（1.0点）がRun1とRun2のスコア差となっている。

---

## Stability Assessment

- **標準偏差（SD）**: 0.5
- **判定**: 高安定（SD ≤ 0.5）
- **解釈**: 結果が信頼できる。2回の実行で高い一貫性を示している。

---

## Notable Observations

### Strengths
1. **重大問題の高検出率**: P01（JWT localStorage）、P02（Webhook署名検証）、P04（レート制限欠如）を両Run共に完全検出
2. **ボーナス獲得の安定性**: 両Run共に6件のボーナス（最大5件制限により3.0点）を獲得
3. **高品質な推奨事項**: 具体的なコード例・設定例を含む詳細な対策提案
4. **ペナルティゼロ**: スコープ外指摘や事実誤認なし

### Weaknesses
1. **中深刻度問題の検出漏れ**: P06（パスワードリセット/メール検証）、P07（動画URL署名）、P08（リソースベース認可）を両Run共に未検出
2. **P03の部分検出**: ファイルアップロード検証の必要性は指摘しているが、Content-Type偽装やマジックバイト検証への具体性不足
3. **録画動画vs.ライブストリーミングの混同**: P07（録画動画の署名付きURL）は未検出だが、ライブストリーミングの署名付きURLはボーナス提案に含まれている

---

## Recommendations for Improvement

1. **中深刻度問題の網羅性向上**: 認証フロー全体（パスワードリセット、メール検証）の欠如を検出するチェックリスト導入
2. **リソースベース認可の検出強化**: API設計における「ロールベース認可」と「リソースベース認可」の区別を明示
3. **ファイル検証の具体性**: Content-Type偽装リスクやマジックバイト検証の必要性を明示的に指摘する基準追加
4. **録画動画とライブストリーミングの区別**: 署名付きURL要件を動画配信モデル別に評価する視点の追加
