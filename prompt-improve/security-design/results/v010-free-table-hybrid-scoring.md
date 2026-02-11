# Scoring Results: v010-free-table-hybrid

## Problem Detection Matrix

| Problem ID | Run1 Detection | Run2 Detection | Justification |
|------------|----------------|----------------|---------------|
| P01: JWTトークンのクライアント保存方式が未定義 | ○ (1.0) | × (0.0) | Run1: Critical Issue #1では"JWT tokens use HS256 signature-only without payload encryption"と指摘し、JWT内容の暗号化について言及しているが、クライアント側の保存方式（localStorage vs httpOnly cookie）には触れていない。Run2: C1で"JWT payloads are base64-encoded, not encrypted"と指摘しているが、クライアント側保存方式には言及なし。両方とも△扱いとしたいが、正解キーの基準では「具体的な保存方式や攻撃ベクトルに触れていない」場合は△。どちらも× |
| P02: パスワードリセットトークンの有効期限が未定義 | ○ (1.0) | ○ (1.0) | Run1: Significant Issue #11で"Lines 157-158 describe password reset flow but no token design (expiration time, single-use enforcement...)"と明確に有効期限の欠如を指摘。Run2: M4で触れているが、S1の中で"Password Reset Token Security Gaps"として"Long-lived tokens enable account takeover if reset email compromised"と指摘している（S1の推奨事項に"15-minute token expiration"あり）。両方とも○ |
| P03: DELETE/PUT APIエンドポイントの認可チェック設計が不明確 | △ (0.5) | ○ (1.0) | Run1: Issue #5で"No input validation policy defined"と一般的な入力検証に触れているが、DELETE/PUT APIの所有者チェックやIDOR脆弱性には具体的に触れていない。Moderate Issue #25, #31で認可の問題に言及があるが、IDORの明示はない。Run2: M6で"Missing Booking Modification Authorization Policy"として`PUT /api/v1/bookings/{id}`の認可不足を指摘しており、「Can users modify other users' bookings?」と明確にIDORリスクに言及。Run1は△、Run2は○ |
| P04: 入力検証の設計方針が未定義 | ○ (1.0) | ○ (1.0) | Run1: Critical Issue #5で"No input validation policy defined"と明確に指摘し、JSONB型カラムの検証にも言及。Run2: S7で"Missing Input Validation Policy"として包括的に指摘。両方とも○ |
| P05: CSRF対策の設計が欠如 | ○ (1.0) | ○ (1.0) | Run1: Critical Issue #4で"No Cross-Site Request Forgery (CSRF) protection mechanism described"と明確に指摘。Run2: C3で"Missing CSRF Protection"として詳細に指摘。両方とも○ |
| P06: Elasticsearchの保存データ暗号化設計が未定義 | ○ (1.0) | ○ (1.0) | Run1: Critical Issue #3で"OpenSearch Service configuration does not specify encryption at rest"と明確に指摘。Run2: S4で"Missing Elasticsearch Encryption Specifications"として詳細に指摘。両方とも○ |
| P07: データベース接続の最小権限原則が未適用 | ○ (1.0) | ○ (1.0) | Run1: Critical Issue #2で"No design for database user privilege separation"と明確に指摘。Run2: S3で"Missing Database Privilege Separation"として詳細に指摘。両方とも○ |
| P08: JWTペイロードの機密情報保護が未設計 | ○ (1.0) | ○ (1.0) | Run1: Critical Issue #1で"Sensitive user data (user_id, role, email) in JWT claims is base64-encoded but readable"と明確に指摘。Run2: C1で"JWT payloads are base64-encoded, not encrypted, making user_id, role, and other claims readable"と明確に指摘。両方とも○ |
| P09: ログ出力における個人情報・機密情報のマスキング方針が未定義 | ○ (1.0) | ○ (1.0) | Run1: Moderate Issue #23で"Lines 266-270 describe structured logging but no PII masking policy"と明確に指摘。Run2: 明示的なマスキング方針の指摘は見当たらないが、M5で"Error Information Disclosure Policy"に触れている。Run2を再確認すると、Infrastructure Security Detailed Assessment tableで"Monitoring"の行に"Audit logging, security event alerting"とあるが、PII maskingの明示なし。Run2は× |

## Re-evaluation for P09

Run2を再度詳細に確認:
- S1 (Missing Audit Logging Specifications): ログの保持期間や監査ログについて言及があるが、PII maskingには触れていない
- M5 (Missing Error Information Disclosure Policy): エラーメッセージの情報漏洩について言及しているが、ログ出力時のPII maskingではない
- Infrastructure Security Detailed Assessment table: "Monitoring"行にaudit loggingの言及はあるが、PII masking明示なし

したがって、Run2のP09は×（未検出）が正しい。

## Updated Problem Detection Matrix

| Problem ID | Run1 Detection | Run2 Detection | Justification |
|------------|----------------|----------------|---------------|
| P01: JWTトークンのクライアント保存方式が未定義 | × (0.0) | × (0.0) | Run1: C1でJWT内容の暗号化について指摘しているが、クライアント側保存方式（localStorage vs httpOnly cookie）には明確に触れていない。Run2: C1でも同様。両方とも× |
| P02: パスワードリセットトークンの有効期限が未定義 | ○ (1.0) | ○ (1.0) | Run1: S11で有効期限の欠如を明確に指摘。Run2: S1の一部で有効期限について言及。両方とも○ |
| P03: DELETE/PUT APIエンドポイントの認可チェック設計が不明確 | △ (0.5) | ○ (1.0) | Run1: M25,M31で認可の問題に触れているが、IDORの明示的指摘は弱い。Run2: M6で明確にIDORリスクを指摘。Run1は△、Run2は○ |
| P04: 入力検証の設計方針が未定義 | ○ (1.0) | ○ (1.0) | Run1: C5で明確に指摘。Run2: S7で明確に指摘。両方とも○ |
| P05: CSRF対策の設計が欠如 | ○ (1.0) | ○ (1.0) | Run1: C4で明確に指摘。Run2: C3で明確に指摘。両方とも○ |
| P06: Elasticsearchの保存データ暗号化設計が未定義 | ○ (1.0) | ○ (1.0) | Run1: C3で明確に指摘。Run2: S4で明確に指摘。両方とも○ |
| P07: データベース接続の最小権限原則が未適用 | ○ (1.0) | ○ (1.0) | Run1: C2で明確に指摘。Run2: S3で明確に指摘。両方とも○ |
| P08: JWTペイロードの機密情報保護が未設計 | ○ (1.0) | ○ (1.0) | Run1: C1で明確に指摘。Run2: C1で明確に指摘。両方とも○ |
| P09: ログ出力における個人情報・機密情報のマスキング方針が未定義 | ○ (1.0) | × (0.0) | Run1: M23で明確に指摘。Run2: マスキング方針の明示的指摘なし。Run1は○、Run2は× |

## Bonus Detection

### Run1 Bonus Issues

1. **Idempotency Guarantees Missing (C6)** - ボーナス対象外（正解キーに含まれる重要な設計要素だが、ボーナスリストに未掲載）
2. **Audit Logging Policy Missing (C7)** - B03に該当: 監査ログ設計の欠如を指摘。**+0.5**
3. **Secret Rotation Policy Absent (C8)** - ボーナス対象外（正解キーには含まれるべき基本事項）
4. **Rate Limiting Insufficient (C9)** - B02に該当: エンドポイント別レート制限の必要性を指摘。**+0.5**
5. **Session Management Security Incomplete (S12)** - B04に該当: セッションタイムアウト設計を指摘。**+0.5**
6. **Redis Authentication and Network Isolation Missing (S17)** - B05に該当: Redis通信暗号化（TLS）を指摘。**+0.5**
7. **Dependency Vulnerability Management Missing (S18)** - B06に該当: 脆弱性スキャン・更新方針の欠如を指摘。**+0.5**
8. **MFA Missing** - B01に該当する指摘なし
9. **Stripe Webhook Signature Verification (M27)** - ボーナス対象外（基本的なAPI統合のセキュリティ）

Run1 Bonus Count: 5件 → 5件 × 0.5 = +2.5点（上限5件到達）

### Run2 Bonus Issues

1. **Missing Idempotency Guarantees (C2)** - ボーナス対象外（正解キーに含まれる重要な設計要素）
2. **Missing Audit Logging Specifications (S1)** - B03に該当: 監査ログ設計の欠如を指摘。**+0.5**
3. **Missing Rate Limiting Specifications Beyond API Gateway (S2)** - B02に該当: エンドポイント別レート制限を指摘。**+0.5**
4. **Missing Redis Encryption Specifications (S5)** - B05に該当: Redis通信暗号化（TLS）を指摘。**+0.5**
5. **Missing Secret Rotation Policy (S6)** - ボーナス対象外（基本的なシークレット管理）
6. **Missing Concurrent Session Handling Policy (M1)** - B04に該当: セッション管理設計の欠如を指摘。**+0.5**
7. **Missing Dependency Vulnerability Scanning (M8)** - B06に該当: 脆弱性スキャンの欠如を指摘。**+0.5**
8. **MFA Missing** - B01に該当する指摘なし

Run2 Bonus Count: 5件 → 5件 × 0.5 = +2.5点（上限5件到達）

## Penalty Detection

### Run1 Penalties

詳細に確認したが、スコープ外の指摘や事実に反する指摘は見当たらない。すべての指摘がセキュリティ設計の範囲内であり、`perspective.md`のスコープに合致している。

Run1 Penalty Count: 0件

### Run2 Penalties

詳細に確認したが、スコープ外の指摘や事実に反する指摘は見当たらない。すべての指摘がセキュリティ設計の範囲内であり、`perspective.md`のスコープに合致している。

Run2 Penalty Count: 0件

## Score Calculation

### Run1
- 検出スコア: P01(0.0) + P02(1.0) + P03(0.5) + P04(1.0) + P05(1.0) + P06(1.0) + P07(1.0) + P08(1.0) + P09(1.0) = 8.5
- ボーナス: 5件 × 0.5 = +2.5（上限到達）
- ペナルティ: 0件 × 0.5 = 0
- **Run1 Total: 8.5 + 2.5 - 0 = 11.0**

### Run2
- 検出スコア: P01(0.0) + P02(1.0) + P03(1.0) + P04(1.0) + P05(1.0) + P06(1.0) + P07(1.0) + P08(1.0) + P09(0.0) = 8.0
- ボーナス: 5件 × 0.5 = +2.5（上限到達）
- ペナルティ: 0件 × 0.5 = 0
- **Run2 Total: 8.0 + 2.5 - 0 = 10.5**

### Summary Statistics
- **Mean: (11.0 + 10.5) / 2 = 10.75**
- **SD: sqrt(((11.0 - 10.75)^2 + (10.5 - 10.75)^2) / 2) = sqrt((0.0625 + 0.0625) / 2) = sqrt(0.0625) = 0.25**

## Detailed Bonus Analysis

### Run1 Bonus Breakdown
1. B03 (Audit Logging): Issue #7 - Audit Logging Policy Missing
2. B02 (Rate Limiting): Issue #9 - Rate Limiting Insufficient (per-endpoint limits)
3. B04 (Session Management): Issue #12 - Session Management Security Incomplete
4. B05 (Data Protection - TLS): Issue #17 - Redis Authentication and Network Isolation (TLS)
5. B06 (Dependency Vulnerability): Issue #18 - Dependency Vulnerability Management Missing

### Run2 Bonus Breakdown
1. B03 (Audit Logging): S1 - Missing Audit Logging Specifications
2. B02 (Rate Limiting): S2 - Missing Rate Limiting Specifications Beyond API Gateway
3. B05 (Data Protection - TLS): S5 - Missing Redis Encryption Specifications (TLS)
4. B04 (Session Management): M1 - Missing Concurrent Session Handling Policy
5. B06 (Dependency Vulnerability): M8 - Missing Dependency Vulnerability Scanning

## Notes

- 両Run共にボーナス上限（5件）に到達
- P01（JWTクライアント保存方式）は両Runとも未検出。JWT内容の暗号化については指摘しているが、クライアント側の保存方式（localStorage vs httpOnly cookie）という核心的な問題には触れていない
- P09（ログのPIIマスキング）はRun1で検出、Run2で未検出という差異が発生
- P03（DELETE/PUT認可チェック）はRun1で部分検出（0.5）、Run2で完全検出（1.0）
- 標準偏差0.25は「高安定」（SD ≤ 0.5）に分類される
