# Scoring Report: v014-hierarchical-table

## Run 1 Scoring Details

### Detection Matrix

| Problem ID | Category | Status | Score | Rationale |
|------------|----------|--------|-------|-----------|
| P01 | JWTトークン有効期限 | × | 0.0 | トークン有効期限24時間の問題に言及なし（JWT storage mechanismの指摘はあるが有効期限には触れず） |
| P02 | パスワードリセットトークン | × | 0.0 | パスワードリセットエンドポイントのトークン管理（有効期限・使用回数制限・配信方法）に関する指摘なし |
| P03 | 注文ステータス更新の認可 | ○ | 1.0 | "Authorization Design - Order status updates: No permission model specified for PATCH /api/v1/orders/{orderId}/status" および "Define role-based authorization matrix: CUSTOMER can cancel (PENDING only), RESTAURANT can confirm/prepare, DRIVER can update delivery status" で明確に検出 |
| P04 | 決済APIの冪等性 | ○ | 1.0 | "Missing Idempotency Guarantees - Payment Service: No idempotency mechanism for POST /api/v1/payments" および "Implement idempotency keys" で明確に検出 |
| P05 | カード情報のPCI DSS | △ | 0.5 | "Data Protection - Payment data: No encryption at rest specification for sensitive data" でpayment card tokensに言及しているが、PCI DSS準拠やトークン化戦略の具体的欠如は指摘していない |
| P06 | 配達先住所の入力検証 | △ | 0.5 | "Input Validation Design - All external inputs: SQL injection, XSS... through order addresses" で住所に言及しているが、delivery_addressフィールドの具体的な検証ルール欠如やSQLインジェクション対策には触れていない |
| P07 | APIレート制限の仕様 | ○ | 1.0 | "Missing Rate Limiting/DoS Protection - Authentication endpoints: No rate limiting specified" および具体的な推奨値（5 attempts/15min for login等）を提示 |
| P08 | ログの機密情報 | ○ | 1.0 | "Data Protection - PII in audit logs: No masking policy for sensitive data in logs" および "mask email, phone, address, card numbers" で明確に検出 |
| P09 | S3バケットのアクセス制御 | ○ | 1.0 | "Storage (S3) - Access policies: Block all public access at bucket level. Use CloudFront signed URLs" でS3のアクセス制御設計欠如を明確に指摘 |

**Detection Score**: 6.0

### Bonus Items (上限5件)

| # | Category | Issue | Score | Rationale |
|---|----------|-------|-------|-----------|
| 1 | 認証設計 | JWT storage mechanism (localStorage vs httpOnly cookies) | +0.5 | B01に該当しないが、認証設計の重要なセキュリティ問題でperspective.mdのスコープ内（XSS token theft risk） |
| 2 | インフラ・依存関係 | Secret management strategy (AWS credentials, DB passwords, JWT keys) | +0.5 | B08に類似するが、より広範な指摘 |
| 3 | 監査ログ設計 | Missing audit logging for orders, payments, admin operations | +0.5 | B02に該当 |
| 4 | 脅威モデリング (CSRF) | CSRF protection for state-changing endpoints | +0.5 | B07に該当 |
| 5 | 認可設計 | Cross-customer data access (IDOR) - ownership checks for orders/payments | +0.5 | B05に該当 |

**Bonus Score**: +2.5

### Penalty Items

なし（全ての指摘がセキュリティスコープ内）

**Penalty Score**: 0

### Run1 Total Score

```
Run1 Score = 6.0 (detection) + 2.5 (bonus) - 0 (penalty) = 8.5
```

---

## Run 2 Scoring Details

### Detection Matrix

| Problem ID | Category | Status | Score | Rationale |
|------------|----------|--------|-------|-----------|
| P01 | JWTトークン有効期限 | × | 0.0 | トークン有効期限24時間の問題に言及なし（JWT storage mechanismの指摘はあるが有効期限には触れず） |
| P02 | パスワードリセットトークン | × | 0.0 | パスワードリセットエンドポイントのトークン管理に関する指摘なし |
| P03 | 注文ステータス更新の認可 | ○ | 1.0 | "Missing Authorization Model: No permission check design or authorization policy beyond JWT authentication" および "customers may access restaurant admin functions, drivers may modify order status without assignment" で明確に検出 |
| P04 | 決済APIの冪等性 | ○ | 1.0 | "Missing Idempotency Guarantees - Payment Processing: No duplicate detection, idempotency keys, or retry handling for payment operations" で明確に検出 |
| P05 | カード情報のPCI DSS | ○ | 1.0 | "Missing Payment Data Handling Policy: No PCI-DSS compliance measures, card data storage policy, or tokenization strategy documented" で明確に検出 |
| P06 | 配達先住所の入力検証 | △ | 0.5 | "Missing Input Validation Policy: SQL injection via order parameters, XSS via delivery address" で住所に言及しているが、delivery_addressの具体的な検証ルール（文字数制限、特殊文字制限）には触れていない |
| P07 | APIレート制限の仕様 | ○ | 1.0 | "Missing Rate Limiting Specifications: Rate limiting mentioned in API Gateway but no specific limits, algorithms, or enforcement policies defined" で明確に検出 |
| P08 | ログの機密情報 | ○ | 1.0 | "Missing Audit Logging Design: Mask PII (card numbers, passwords)" でログの機密情報マスキング欠如を指摘 |
| P09 | S3バケットのアクセス制御 | ○ | 1.0 | "Storage (S3) - Missing: no access control policy, encryption, or versioning specified" および "Implement bucket policies with least privilege" で明確に検出 |

**Detection Score**: 7.5

### Bonus Items (上限5件)

| # | Category | Issue | Score | Rationale |
|---|----------|-------|-------|-----------|
| 1 | 認証設計 | Missing JWT Storage Specification (httpOnly cookies) | +0.5 | XSS token theft riskを指摘する重要な認証設計の問題 |
| 2 | インフラ・依存関係 | Missing Secrets Management Design (AWS Secrets Manager/Parameter Store) | +0.5 | B08に類似 |
| 3 | 脅威モデリング (CSRF) | Missing CSRF Protection for state-changing endpoints | +0.5 | B07に該当 |
| 4 | 監査ログ設計 | Missing Audit Logging Design for critical operations | +0.5 | B02に該当 |
| 5 | 認証設計 | Missing Session Management Policy (token timeout, revocation) | +0.5 | セッション管理の重要な問題（refresh token 30日有効期限のリスク指摘） |

**Bonus Score**: +2.5

### Penalty Items

なし（全ての指摘がセキュリティスコープ内）

**Penalty Score**: 0

### Run2 Total Score

```
Run2 Score = 7.5 (detection) + 2.5 (bonus) - 0 (penalty) = 10.0
```

---

## Summary Statistics

| Metric | Value |
|--------|-------|
| Mean Score | 9.25 |
| Standard Deviation | 0.75 |
| Run1 Score | 8.5 (検出6.0+bonus5-penalty0) |
| Run2 Score | 10.0 (検出7.5+bonus5-penalty0) |

### Stability Assessment

- **SD = 0.75** → **中安定** (0.5 < SD ≤ 1.0)
- 結果の傾向は信頼できるが、個別の実行で変動がある

### Key Findings

**Run1とRun2の主な差異**:
- **P05 (PCI DSS)**: Run1は△、Run2は○ → Run2でより明確にPCI DSS準拠・トークン化戦略の欠如を指摘
- **全体的な表現**: Run2の方が問題のカテゴリ化と構造化が明確（Critical/Significant/Moderate分類、Infrastructure Security Assessment表）

**共通の検出漏れ**:
- **P01 (JWTトークン有効期限24時間)**: 両実行とも未検出
- **P02 (パスワードリセットトークン)**: 両実行とも未検出

**安定して検出された問題**:
- P03 (注文ステータス更新の認可)
- P04 (決済APIの冪等性)
- P07 (APIレート制限の仕様)
- P08 (ログの機密情報)
- P09 (S3バケットのアクセス制御)
