# 採点結果: v005-missing-detection

## 実行条件
- **観点**: security
- **対象**: design
- **バリアント**: v005-missing-detection
- **実行回数**: 2 (Run1, Run2)
- **埋め込み問題数**: 9問

---

## Run1 採点結果

### 検出マトリクス

| 問題ID | カテゴリ | 判定 | スコア | 根拠 |
|-------|---------|-----|-------|------|
| P01 | JWT有効期限が長すぎる | ○ | 1.0 | Section 1.1で「24-hour expiration means stolen tokens remain valid for a full day」と指摘し、「Reduce access token to 15 minutes, implement refresh token」を提案 |
| P02 | JWT署名アルゴリズム・鍵管理未定義 | △ | 0.5 | Section 1.1でJWTのストレージとセッション管理に言及しているが、署名アルゴリズムや鍵管理の欠如については明示的に指摘していない |
| P03 | 他院共有の認可設計が不明確 | ○ | 1.0 | Section 2.4で「No design for how consent is obtained, who can toggle the flag, or audit trail for consent changes」と指摘し、Consent API設計を提案 |
| P04 | 入力検証方針の欠如 | ○ | 1.0 | Section 1.4で「No input validation policy defined」「SQL injection vulnerabilities if queries are constructed with string concatenation」と指摘し、具体的な検証方針を提案 |
| P05 | 予約キャンセルAPIの冪等性未定義 | ○ | 1.0 | Section 2.3で「Network failures or user double-clicks could cause duplicate payments or double-booking without idempotency guarantees」と指摘し、idempotency key mechanismを提案 |
| P06 | 監査ログの記録範囲が不十分 | ○ | 1.0 | Section 1.2で「No audit logging design for access to medical records」と指摘し、「誰が、いつ、どの患者のカルテにアクセスしたか」の記録必要性を明記 |
| P07 | データベース内の暗号化対象が限定的 | △ | 0.5 | Section 1.3で暗号化に言及しているが、暗号化対象が診断内容・処方箋に限定されている点や他の個人情報の暗号化必要性については明示的に指摘していない（鍵管理の欠如が主）|
| P08 | APIレート制限の設計が不十分 | ○ | 1.0 | Section 2.1で「60 requests/minute per user rate limiting, but this is insufficient for login endpoints」と指摘し、未認証ユーザー・ログイン試行への独立したレート制限を提案 |
| P09 | エラーメッセージで内部情報が露出 | ○ | 1.0 | Section 2.8で「does not specify what information should be hidden from API responses」と指摘し、環境別エラーメッセージ切り替えを提案 |

**検出スコア合計**: 8.0

### ボーナス・ペナルティ

#### ボーナス候補（スコープ内の追加指摘）

1. **Section 1.5**: File upload security (医療画像・PDFアップロードのセキュリティ設計欠如)
   - ファイルタイプ検証、サイズ制限、マルウェアスキャン、S3アクセス制御の欠如を指摘
   - **判定**: ○ ボーナス（B03相当: S3バケットのアクセス制御方針不明確に該当）
   - **スコア**: +0.5

2. **Section 2.2**: CSRF protection (CSRF保護の欠如)
   - JWT + localStorageパターンにおけるCSRF脆弱性を指摘
   - **判定**: ○ ボーナス（正解キー未掲載、スコープ内の有益な指摘）
   - **スコア**: +0.5

3. **Section 2.5**: Database connection encryption (DB接続暗号化とクレデンシャル管理)
   - PostgreSQL接続のTLS欠如、Secrets Manager使用欠如を指摘
   - **判定**: ○ ボーナス（正解キー未掲載、スコープ内の有益な指摘）
   - **スコア**: +0.5

4. **Section 2.6**: Session timeout (セッションタイムアウトの欠如)
   - 24時間トークン有効期限に加えて、非アクティブタイムアウトの欠如を指摘
   - **判定**: ○ ボーナス（P01の延長だが、独立した有益な指摘）
   - **スコア**: +0.5

5. **Section 2.7**: WAF rules specification (WAF ルールの詳細設計欠如)
   - **判定**: ○ ボーナス（B04相当）
   - **スコア**: +0.5

**ボーナス合計**: +2.5（5件、上限5件未満）

#### ペナルティ候補

検証結果: スコープ外指摘や事実に反する指摘は確認されず。

**ペナルティ合計**: 0

### Run1 総合スコア

```
Run1スコア = 検出スコア + ボーナス - ペナルティ
         = 8.0 + 2.5 - 0
         = 10.5
```

---

## Run2 採点結果

### 検出マトリクス

| 問題ID | カテゴリ | 判定 | スコア | 根拠 |
|-------|---------|-----|-------|------|
| P01 | JWT有効期限が長すぎる | △ | 0.5 | Section 1.2でJWT認証に言及しているが、有効期限24時間が長すぎることの明示的指摘はなし（トークンストレージとリフレッシュトークンには言及）|
| P02 | JWT署名アルゴリズム・鍵管理未定義 | ○ | 1.0 | Section 1.2で「How JWT signing keys are generated, stored, and rotated」「Whether symmetric (HMAC) or asymmetric (RSA/ECDSA) signing is used」の欠如を明示的に指摘 |
| P03 | 他院共有の認可設計が不明確 | ○ | 1.0 | Section 3.1で「does not specify how patient consent is obtained, who can toggle the flag, or audit trail for consent changes」と指摘 |
| P04 | 入力検証方針の欠如 | ○ | 1.0 | Section 1.1で「completely lacks any input validation policy or injection prevention measures」と指摘し、SQL injection・XSS・入力検証ルールの必要性を明記 |
| P05 | 予約キャンセルAPIの冪等性未定義 | ○ | 1.0 | Section 2.8で「does not specify idempotency handling」と指摘し、idempotency key patternを提案 |
| P06 | 監査ログの記録範囲が不十分 | ○ | 1.0 | Section 1.4で「does not specify audit logging for security-critical operations」と指摘し、「誰が、いつ、どの患者のカルテにアクセスしたか」の記録必要性を明記 |
| P07 | データベース内の暗号化対象が限定的 | △ | 0.5 | Section 2.1でAES-256暗号化に言及しているが、暗号化対象が診断内容・処方箋に限定されている点については明示的に指摘していない（鍵管理の欠如が主）|
| P08 | APIレート制限の設計が不十分 | ○ | 1.0 | Section 2.4で「60 req/min per user does not apply to login endpoints」と指摘し、未認証ユーザー・ログイン試行への独立したレート制限を提案 |
| P09 | エラーメッセージで内部情報が露出 | ○ | 1.0 | Section 2.6で「does not specify what information should be hidden from API responses」と指摘し、環境別エラーメッセージ切り替えを提案 |

**検出スコア合計**: 8.0

### ボーナス・ペナルティ

#### ボーナス候補

1. **Section 1.3**: Session invalidation (セッション無効化機構の欠如)
   - トークン失効機構の欠如、パスワード変更後のトークン有効性を指摘
   - **判定**: ○ ボーナス（P01の延長だが、独立した重要な指摘）
   - **スコア**: +0.5

2. **Section 1.5**: Multi-factor authentication (医療スタッフのMFA欠如)
   - **判定**: ○ ボーナス（B02相当）
   - **スコア**: +0.5

3. **Section 2.2**: Data retention and deletion policy (データ保持・削除ポリシー欠如)
   - 医療データの保持期間、GDPR対応削除ポリシーの欠如を指摘
   - **判定**: ○ ボーナス（正解キー未掲載、スコープ内の有益な指摘）
   - **スコア**: +0.5

4. **Section 2.3**: CSRF protection (CSRF保護の欠如)
   - **判定**: ○ ボーナス（正解キー未掲載、スコープ内の有益な指摘）
   - **スコア**: +0.5

5. **Section 2.5**: Database connection encryption (DB接続暗号化)
   - **判定**: ○ ボーナス（正解キー未掲載、スコープ内の有益な指摘）
   - **スコア**: +0.5

**ボーナス合計**: +2.5（5件、上限5件未満）

#### ペナルティ候補

検証結果: スコープ外指摘や事実に反する指摘は確認されず。

**ペナルティ合計**: 0

### Run2 総合スコア

```
Run2スコア = 検出スコア + ボーナス - ペナルティ
         = 8.0 + 2.5 - 0
         = 10.5
```

---

## 統計サマリ

### スコア統計

| 指標 | 値 |
|-----|-----|
| Run1スコア | 10.5 |
| Run2スコア | 10.5 |
| 平均 (Mean) | 10.5 |
| 標準偏差 (SD) | 0.0 |
| 安定性判定 | 高安定 (SD ≤ 0.5) |

### 検出率統計

| 指標 | Run1 | Run2 |
|-----|------|------|
| 完全検出 (○) | 8問 | 7問 |
| 部分検出 (△) | 1問 | 2問 |
| 未検出 (×) | 0問 | 0問 |
| 検出率 | 100% | 100% |

### 問題別検出比較

| 問題ID | Run1 | Run2 | 備考 |
|-------|------|------|------|
| P01 | ○ (1.0) | △ (0.5) | Run2ではトークン有効期限の長さへの明示的指摘が弱い |
| P02 | △ (0.5) | ○ (1.0) | Run2では署名アルゴリズム・鍵管理の欠如を明示的に指摘 |
| P03 | ○ (1.0) | ○ (1.0) | 両方とも検出 |
| P04 | ○ (1.0) | ○ (1.0) | 両方とも検出 |
| P05 | ○ (1.0) | ○ (1.0) | 両方とも検出 |
| P06 | ○ (1.0) | ○ (1.0) | 両方とも検出 |
| P07 | △ (0.5) | △ (0.5) | 両方とも暗号化対象の限定性への明示的指摘が弱い |
| P08 | ○ (1.0) | ○ (1.0) | 両方とも検出 |
| P09 | ○ (1.0) | ○ (1.0) | 両方とも検出 |

---

## 詳細分析

### Run1の特徴

**強み**:
- P01（JWT有効期限）を明確に検出（「24-hour expiration means stolen tokens remain valid for a full day」）
- File upload security（Section 1.5）という正解キー未掲載の重要な脆弱性を検出

**弱み**:
- P02（JWT署名アルゴリズム・鍵管理）への言及が間接的（Section 1.1でストレージとセッション管理が主、署名・鍵管理は部分的）

### Run2の特徴

**強み**:
- P02（JWT署名アルゴリズム・鍵管理）を明確に検出（Section 1.2で「How JWT signing keys are generated, stored, and rotated」を明示）
- MFA欠如（Section 1.5）という正解キー未掲載の重要な脆弱性を検出

**弱み**:
- P01（JWT有効期限）への明示的指摘が弱い（トークンストレージとリフレッシュトークンには言及しているが、24時間有効期限が長すぎることの直接的指摘は不明確）

### 共通の改善機会

- P07（暗号化対象の限定性）: 両実行とも鍵管理の欠如には言及しているが、「診断内容・処方箋のみが暗号化対象で、氏名・生年月日・電話番号等が未暗号化」という暗号化対象範囲の限定性への明示的指摘が弱い

---

## 結論

v005-missing-detectionバリアントは、2回の実行で完全に一致したスコア（10.5点）を達成し、標準偏差0.0という極めて高い安定性を示した。

9問中7-8問を完全検出（○）、1-2問を部分検出（△）し、未検出（×）は0問。検出率100%を達成している。

ボーナス指摘も両実行で5件ずつ獲得しており、正解キー未掲載の重要な脆弱性（CSRF保護、DB接続暗号化、MFA欠如など）を安定的に検出できている。

Run1とRun2の間でP01とP02の検出精度が相補的に変動しているが、総合スコアへの影響は相殺されており、高い再現性を示している。
