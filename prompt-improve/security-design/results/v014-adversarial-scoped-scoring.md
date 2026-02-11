# Scoring Report: v014-adversarial-scoped

## Detection Matrix

| Problem ID | Description | Run1 | Run2 | Score (Run1) | Score (Run2) |
|-----------|-------------|------|------|--------------|--------------|
| P01 | JWTトークンの有効期限が長すぎる | × | × | 0.0 | 0.0 |
| P02 | パスワードリセットトークンのセキュリティ仕様が不明確 | × | × | 0.0 | 0.0 |
| P03 | 注文ステータス更新APIの認可設計が不十分 | ○ | ○ | 1.0 | 1.0 |
| P04 | 決済APIにおける冪等性とリプレイ攻撃対策の欠如 | × | × | 0.0 | 0.0 |
| P05 | データベースのカード情報保存がPCI DSS違反リスク | ○ | ○ | 1.0 | 1.0 |
| P06 | 配達先住所の入力検証とインジェクション対策の欠如 | △ | △ | 0.5 | 0.5 |
| P07 | API レート制限の仕様が不明確 | ○ | ○ | 1.0 | 1.0 |
| P08 | ログにクレジットカード情報や個人情報が記録されるリスク | ○ | ○ | 1.0 | 1.0 |
| P09 | S3バケットのアクセス制御とパブリック公開設定の未定義 | ○ | ○ | 1.0 | 1.0 |

### Detection Rationale

**P01 (JWTトークンの有効期限が長すぎる) - Run1: ×, Run2: ×**
- Run1では「トークン有効期限: 24時間」について"JWT Storage Vulnerability"セクションで言及しているが、**有効期限が長すぎることの指摘や短縮の推奨がない**。XSS+token theftの文脈で言及されているのみ。
- Run2でも「JWT Expiration: 24-hour token expiration limits stolen token lifetime」として**肯定的に評価**しており、長すぎるという指摘はない。
- 両Run共に検出基準「JWTトークンの有効期限24時間が長すぎることを指摘し、短縮（1時間以内など）を推奨している」を満たさない。

**P02 (パスワードリセットトークンのセキュリティ仕様が不明確) - Run1: ×, Run2: ×**
- 両Run共にパスワードリセットトークンの有効期限、使用回数制限、配信方法に関する具体的な指摘がない。
- Run1では`/auth/password-reset`の言及はあるが、トークン管理の具体的な問題点は指摘していない。
- Run2では"Email Injection"攻撃でpassword-reset endpointを例示しているが、トークンのセキュリティ仕様には触れていない。

**P03 (注文ステータス更新APIの認可設計が不十分) - Run1: ○, Run2: ○**
- Run1: Section 2で詳細に指摘「PATCH /api/v1/orders/{orderId}/status — Status Manipulation」として、ロール別の認可ルールが不明確であることを指摘し、具体的な推奨仕様を提示。
- Run2: "C2. Missing Authorization for Order Status Updates"として**Critical Issue**に分類し、ロール別ステータス遷移マトリクスの欠如を指摘。
- 両Run共に検出基準を満たす。

**P04 (決済APIにおける冪等性とリプレイ攻撃対策の欠如) - Run1: ×, Run2: ×**
- 両Run共に決済APIの冪等性キーやリプレイ攻撃対策（nonce/タイムスタンプ検証）に関する具体的な指摘がない。
- Run1では"Payment Manipulation"で認可の問題を指摘しているが、冪等性には触れていない。
- Run2では"Missing Authorization for Payment Initiation"で認可を指摘しているが、冪等性/リプレイ攻撃には言及なし。

**P05 (データベースのカード情報保存がPCI DSS違反リスク) - Run1: ○, Run2: ○**
- Run1: Section 3で「Payment Data Storage」として、PCI DSS準拠の欠如、トークン化要件の必要性を明確に指摘。
- Run2: "C4. Payment Card Data Storage Without PCI-DSS Specification"として**Critical Issue**に分類し、トークン化戦略の欠如を指摘。
- 両Run共に検出基準を満たす。

**P06 (配達先住所の入力検証とインジェクション対策の欠如) - Run1: △, Run2: △**
- Run1: Section 4で「XSS Vectors (Design-Level)」として`delivery_address`フィールドのXSS問題を指摘しているが、**SQLインジェクション対策は明示的に言及されていない**（"Mitigation Status: Partial. Section 2 specifies Hibernate 6.2 (ORM)"として、ORM利用でSQLインジェクションは緩和されると述べている）。
- Run2: "M1. Delivery Address Not Validated for PII Injection"で検証の欠如を指摘しているが、**SQLインジェクションには触れていない**。また、"S6. Missing Input Validation Specification"でSQL injectionを一般論として扱っているが、delivery_addressの具体的なリスクとは結びついていない。
- 両Run共に入力検証の必要性には言及しているが、**SQLインジェクション対策の明示的な指摘が不十分**。部分検出と判定。

**P07 (API レート制限の仕様が不明確) - Run1: ○, Run2: ○**
- Run1: Section 1 (STRIDE - Denial of Service)で「No Rate Limiting Specifications」として、具体的なレート制限値、スコープ、enforcement policyの欠如を詳細に指摘。
- Run2: "C5. Missing Rate Limiting Specification on Authentication Endpoints"として**Critical Issue**に分類し、レート制限閾値とロックアウトポリシーの欠如を指摘。
- 両Run共に検出基準を満たす。

**P08 (ログにクレジットカード情報や個人情報が記録されるリスク) - Run1: ○, Run2: ○**
- Run1: Section 1 (STRIDE - Information Disclosure)で「Missing PII Masking in Logs」として、機密情報のマスキング・除外ルールの欠如を指摘。Section 3でも"PII in Logs"として詳細に分析。
- Run2: "S2. Sensitive Data in Application Logs"として、PII/sensitive dataマスキングの欠如を指摘。
- 両Run共に検出基準を満たす。

**P09 (S3バケットのアクセス制御とパブリック公開設定の未定義) - Run1: ○, Run2: ○**
- Run1: Section 5のInfrastructure Security Assessmentテーブルで「Storage (S3)」のアクセスポリシー、encryption at rest、CloudFront signed URLsの欠如を指摘。
- Run2: Infrastructure Security Analysisテーブルで「S3 Storage」のbucket policy、encryption at rest、versioningの欠如を指摘。
- 両Run共に検出基準を満たす。

---

## Bonus/Penalty Assessment

### Run 1

**Bonus Candidates:**

1. **IDOR prevention (GET /api/v1/orders)** - B05相当
   - Section 2 "GET /api/v1/orders — Horizontal Privilege Escalation"で詳細に指摘
   - セキュリティスコープ内、事実に基づく有益な指摘
   - **Bonus: +0.5**

2. **Password reset endpoint security (account enumeration)**
   - Section "Missing Rate Limiting Specifications"でaccount enumerationリスクを指摘
   - セキュリティスコープ内、有益な指摘
   - **Bonus: +0.5**

3. **JWT token storage mechanism (XSS-based token theft)** - セキュリティスコープ内の重要な指摘
   - Section 2 "JWT Storage Vulnerability (XSS-based Token Theft)"で詳細分析
   - セキュリティスコープ内、事実に基づく有益な指摘
   - **Bonus: +0.5**

4. **Database encryption at rest (RDS)** - B03相当
   - Section 3 "Encryption Gaps - Data at Rest"でRDS TDE/encryption at restの欠如を指摘
   - **Bonus: +0.5**

5. **Redis authentication and encryption** - B04相当
   - Infrastructure Security Assessmentテーブルで「ElastiCache: No authentication mechanism specified (Redis AUTH?), no encryption at rest, no encryption in transit」を指摘
   - **Bonus: +0.5**

**Total Bonus: 5件 (上限到達)**

**Penalty: なし**

---

### Run 2

**Bonus Candidates:**

1. **IDOR prevention (GET /api/v1/orders)** - B05相当
   - "C1. Missing Object-Level Authorization (IDOR) on Order Endpoints"で詳細に指摘
   - **Bonus: +0.5**

2. **JWT token storage mechanism (XSS-based token theft)**
   - "C3. JWT Storage Mechanism Unspecified (XSS-Based Token Theft Risk)"で詳細分析
   - **Bonus: +0.5**

3. **Database encryption at rest (RDS)** - B03相当
   - "M4. PostgreSQL Encryption at Rest Not Specified"で指摘
   - **Bonus: +0.5**

4. **Redis authentication and encryption** - B04相当
   - Infrastructure Security Analysisテーブルで「Redis ElastiCache: If Redis exposed or no AUTH, attacker can: read session tokens, flush cache (DoS), inject malicious session data. Missing: AUTH enabled, encryption in transit/at rest, VPC isolation」を指摘
   - **Bonus: +0.5**

5. **Audit logging for critical actions** - B02相当
   - "M3. Insufficient Logging for Audit Trail"で注文ステータス変更、決済返金、ロール変更の監査ログ欠如を指摘
   - **Bonus: +0.5**

**Total Bonus: 5件 (上限到達)**

**Penalty: なし**

---

## Score Summary

### Run 1
- Detection Score: 5.5 (P03: 1.0, P05: 1.0, P06: 0.5, P07: 1.0, P08: 1.0, P09: 1.0)
- Bonus: +2.5 (5件)
- Penalty: -0.0
- **Total: 8.0**

### Run 2
- Detection Score: 5.5 (P03: 1.0, P05: 1.0, P06: 0.5, P07: 1.0, P08: 1.0, P09: 1.0)
- Bonus: +2.5 (5件)
- Penalty: -0.0
- **Total: 8.0**

### Statistics
- **Mean: 8.0**
- **Standard Deviation: 0.0**
- **Stability: 高安定 (SD = 0.0 ≤ 0.5)**

---

## Key Strengths

1. **認可設計の問題検出**: 両Runで注文ステータス更新APIの認可不足を詳細に指摘（ロール別権限分離の欠如）
2. **IDOR脆弱性の特定**: GET /api/v1/ordersのオブジェクトレベル認可欠如を具体的な攻撃シナリオで説明
3. **インフラセキュリティ**: データベース暗号化、Redisセキュリティ、S3アクセス制御の欠如を包括的に指摘
4. **XSS-based token theft分析**: JWT storage mechanismの未定義を攻撃者視点で詳細分析
5. **レート制限**: API Gateway仕様の具体的な不足（閾値、スコープ、enforcement policy）を明確化

---

## Key Weaknesses

1. **JWT有効期限問題の見落とし (P01)**: 24時間が長すぎることを指摘せず、むしろRun2では肯定的に評価
2. **パスワードリセットトークン仕様の見落とし (P02)**: トークン有効期限、使用回数制限、配信方法のセキュリティ要件に触れず
3. **決済API冪等性の見落とし (P04)**: 冪等性キー、リプレイ攻撃対策（nonce/タイムスタンプ検証）に言及なし
4. **入力検証の部分検出 (P06)**: delivery_addressのXSS問題は指摘したが、SQLインジェクション対策の明示的な推奨が不足

---

## Notable Observations

- **安定性**: SD = 0.0（完全に同一スコア）は、同一プロンプトが極めて安定した検出パターンを示すことを実証
- **Adversarial Perspectiveの強み**: 攻撃シナリオベースの分析により、IDOR/JWT theft/authorization bypassなどの実践的な脆弱性を効果的に検出
- **包括性**: Infrastructure Security Assessmentテーブルによる構造化分析で、RDS/Redis/S3/API Gateway/Secrets管理の広範な問題をカバー
- **Critical Issueの適切な優先順位付け**: 両Runで認可・認証・データ保護の問題をCritical/Significantに分類し、実用的な優先度を提示
