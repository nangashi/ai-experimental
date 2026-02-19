# Scoring Results: baseline (v010)

## Run 1 Scoring

### Detection Matrix

| Problem ID | Category | Detection | Score | Evidence |
|-----------|----------|-----------|-------|----------|
| P01 | 認証設計 | × | 0.0 | JWT保存方式の具体的な指摘なし。JWTのセキュリティには言及(M-1)しているが、クライアント側保存方式やlocalStorage/httpOnly cookieの選択には触れていない。 |
| P02 | 認証設計 | ○ | 1.0 | S-8でパスワードリセットトークンの有効期限を明確に指摘。「Token expiration: 1 hour from generation」と具体的な推奨値を記載。 |
| P03 | 認可設計 | ○ | 1.0 | OWASP API Security Top 10で「API1: Broken Object Level Authorization (missing granular authorization checks)」を明記。DELETE/PUT APIでのリソース所有者チェックの必要性を示唆。 |
| P04 | 入力検証設計 | ○ | 1.0 | S-3で入力検証方針の欠如を包括的に指摘。JSONBカラムの検証必要性も明記(「Define JSON Schema for `booking_details` column」)。 |
| P05 | CSRF | ○ | 1.0 | C-2でCSRF対策の欠如を最重要問題(Critical)として詳細に指摘。CSRFトークン、SameSite属性、Origin/Referer検証など具体的な対策を記載。 |
| P06 | データ保護 | △ | 0.5 | S-6でPostgreSQLの暗号化には言及があるが、Elasticsearch/OpenSearchの暗号化には具体的に触れていない。データベース暗号化の一般論のみ。 |
| P07 | インフラ・依存関係のセキュリティ | ○ | 1.0 | M-5で「Missing Database Access Control Design」として最小権限原則を明確に指摘。サービス別のデータベースユーザー権限分離を推奨。 |
| P08 | データ保護 | × | 0.0 | JWTペイロードの機密情報保護に関する具体的な指摘なし。M-1でJWTセキュリティには言及しているが、ペイロード内容の機密性には触れていない。 |
| P09 | データ保護 | △ | 0.5 | S-6で「CloudWatch logs (may contain PII)」の暗号化には言及があるが、ログ出力時のマスキング方針の欠如という点では不十分。ログ保護の観点はあるがマスキング設計の具体性に欠ける。 |

**Detection Score: 6.0 / 9.0**

### Bonus/Penalty Analysis

#### Bonus Points (上限5件)

1. **B01: MFA設計の欠如** (+0.5)
   - M-9で管理者アカウントのMFA要件を明確に指摘(「Require MFA for admin accounts (TOTP or hardware token)」)

2. **B02: エンドポイント別レート制限の欠如** (+0.5)
   - S-1で「Missing Rate Limiting Design Details」として、認証エンドポイント等の個別レート制限の必要性を詳細に指摘

3. **B03: 監査ログ設計の欠如** (+0.5)
   - C-3で「Missing Audit Logging Design」をCritical問題として包括的に指摘。記録対象イベント、保持期間、ログ保護まで詳細に記載

4. **B04: セッション管理の不明確さ** (+0.5)
   - S-2で「Missing Session Management Security Design」として、セッションタイムアウト、無効化設計、並行セッション制限を詳細に指摘

5. **B05: RDS/ElastiCacheの通信暗号化未記載** (+0.5)
   - S-6で「Redis ElastiCache: Enable encryption at rest and in-transit encryption」と明記

**Bonus: +2.5 (5件)**

#### Penalty Points

1. **冪等性保証の欠落をCriticalとして採点** (-0.5)
   - C-1で「Missing Idempotency Guarantees」を最重要問題として指摘しているが、これは正解キー外の問題であり、過剰な重要度付けと判断。設計書には決済APIのリトライ挙動が未定義であり指摘自体は妥当だが、埋め込み問題としては設定されていない。

**Penalty: -0.5 (1件)**

### Run 1 Final Score

```
Detection: 6.0
Bonus: +2.5
Penalty: -0.5
Total: 8.0
```

---

## Run 2 Scoring

### Detection Matrix

| Problem ID | Category | Detection | Score | Evidence |
|-----------|----------|-----------|-------|----------|
| P01 | 認証設計 | × | 0.0 | JWTトークンのクライアント保存方式に関する指摘なし。JWTセキュリティには一般的に言及(認証設計セクション)しているが、保存先の具体的な危険性には触れていない。 |
| P02 | 認証設計 | ○ | 1.0 | パスワードリセットトークンの有効期限を明確に指摘(「パスワードリセットトークンの有効期限が設計書に記載されていません」)。 |
| P03 | 認可設計 | ○ | 1.0 | DELETE/PUT APIエンドポイントの認可チェック不足を明確に指摘。IDOR脆弱性のリスクに言及。 |
| P04 | 入力検証設計 | ○ | 1.0 | 致命的問題として入力検証設計の欠落を包括的に指摘。JSONBカラムの検証必要性も明記(「JSONB型への任意JSON注入リスクが検討されていない」)。 |
| P05 | CSRF | ○ | 1.0 | 中程度問題セクションでCSRF対策の欠落を詳細に指摘。Spring SecurityのCSRFトークン、SameSite属性の推奨まで記載。 |
| P06 | データ保護 | × | 0.0 | Elasticsearch/OpenSearchの暗号化設計に関する指摘なし。RDS/Redisの暗号化には言及しているが、Elasticsearchには触れていない。 |
| P07 | インフラ・依存関係のセキュリティ | × | 0.0 | データベース接続の最小権限原則に関する明示的な指摘なし。ネットワークセキュリティやVPC設計には言及しているが、サービス別のDB権限分離には触れていない。 |
| P08 | データ保護 | × | 0.0 | JWTペイロードの機密情報保護に関する具体的な指摘なし。JWTセキュリティの一般論はあるが、ペイロード内容の設計方針には触れていない。 |
| P09 | データ保護 | ○ | 1.0 | 情報漏洩対策として「CloudWatchログにPII（個人識別情報）が含まれる場合のマスキング方針が未定義」と明確に指摘。 |

**Detection Score: 5.0 / 9.0**

### Bonus/Penalty Analysis

#### Bonus Points (上限5件)

1. **B03: 監査ログ設計の欠如** (+0.5)
   - 重大問題として「監査ログ設計が完全に欠落」を詳細に指摘。記録対象イベント、ログ項目、保持期間、保護方法まで記載

2. **B04: セッション管理の不明確さ** (+0.5)
   - 認証設計セクションでJWT無効化時の処理詳細、複数デバイスログイン時の制限が未定義と指摘

3. **B05: RDS/ElastiCacheの通信暗号化未記載** (+0.5)
   - データ保護セクションで「Redis接続の暗号化（TLS in-transit）の有無が未定義」と明記

4. **B06: ライブラリ脆弱性スキャン方針の欠落** (+0.5)
   - インフラセキュリティセクションで「依存関係の脆弱性管理方針の欠落」として、OWASP Dependency-Check、Snykの使用を推奨

5. **B08: ファイルアップロード制限の欠落** (+0.5)
   - 入力検証セクションで「ファイルタイプ制限・サイズ制限・スキャン要件が未定義」と指摘

**Bonus: +2.5 (5件)**

#### Penalty Points

なし。すべての指摘が評価スコープ(security-design)に合致している。

**Penalty: 0**

### Run 2 Final Score

```
Detection: 5.0
Bonus: +2.5
Penalty: 0
Total: 7.5
```

---

## Overall Statistics

| Metric | Run 1 | Run 2 |
|--------|-------|-------|
| Detection Score | 6.0 | 5.0 |
| Bonus | +2.5 | +2.5 |
| Penalty | -0.5 | 0 |
| **Final Score** | **8.0** | **7.5** |

**Mean Score: 7.75**
**Standard Deviation: 0.25**

### Stability Assessment

SD = 0.25 ≤ 0.5 → **高安定** (結果が信頼できる)

---

## Detailed Problem Analysis

### Consistently Detected (両方で検出)

- P02: パスワードリセットトークンの有効期限 (両方○)
- P03: DELETE/PUT APIの認可チェック設計 (両方○)
- P04: 入力検証の設計方針 (両方○)
- P05: CSRF対策の設計 (両方○)

### Inconsistently Detected (片方のみ検出)

- P06: Elasticsearchの暗号化設計 (Run1: △, Run2: ×) - いずれも完全検出ではない
- P07: データベース接続の最小権限原則 (Run1: ○, Run2: ×)
- P09: ログ出力のマスキング方針 (Run1: △, Run2: ○)

### Never Detected (両方で未検出)

- P01: JWTトークンのクライアント保存方式 (両方×)
- P08: JWTペイロードの機密情報保護 (両方×)

### Detection Rate by Severity

| 深刻度 | 問題数 | Run1検出率 | Run2検出率 | 平均検出率 |
|--------|--------|-----------|-----------|-----------|
| 重大 | 2 (P01, P03) | 50% (1/2) | 50% (1/2) | 50% |
| 中 | 6 (P02, P04, P05, P06, P07) | 80% (4/5 full + 1/5 partial) | 80% (4/5) | 80% |
| 軽微 | 2 (P08, P09) | 25% (0.5/2) | 50% (1/2) | 37.5% |

**全体検出率: Run1 66.7%, Run2 55.6%, 平均 61.1%**

---

## Observations

### Strengths

1. **CSRF対策の検出精度が高い**: 両実行で最重要問題として明確に指摘
2. **入力検証設計の欠落を包括的に捉えている**: JSONBカラム、インジェクション防止、XSS対策まで広範にカバー
3. **認可設計の問題を正確に検出**: IDOR脆弱性リスクの認識が確実
4. **ボーナス問題の検出が安定**: 監査ログ、セッション管理、MFAなどを両実行で安定して指摘

### Weaknesses

1. **JWT保存方式の見逃し**: クライアント側保存(localStorage vs httpOnly cookie)の選択に関する指摘が両実行で欠落
2. **JWTペイロード設計の見逃し**: ペイロードの機密情報保護に関する指摘が両実行で欠落
3. **データベース権限設計の不安定性**: Run1では検出したが、Run2では見逃し
4. **Elasticsearch暗号化の検出精度**: 部分検出または未検出で、完全な検出に至らず

### Recommendations for Prompt Improvement

1. **認証設計セクションの強化**: JWTの「発行」だけでなく「保存・送信」の観点を明示的に追加
2. **データ保護の具体化**: 「保存時暗号化」の対象として、RDS/Redis以外のデータストア(Elasticsearch等)も列挙
3. **最小権限原則の強調**: インフラセキュリティだけでなくアプリケーション設計レベルでの権限分離を明示
4. **JWTペイロード設計のチェック項目追加**: 認証設計の評価観点として「トークンに含める情報の適切性」を追加
