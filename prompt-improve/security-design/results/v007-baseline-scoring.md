# Scoring Result: baseline

## Run1 Detection Matrix

| Problem | Detection | Score | Evidence |
|---------|-----------|-------|----------|
| P01: JWTトークンのlocalStorage保存によるXSS脆弱性 | ○ | 1.0 | Section 1-1 explicitly identifies localStorage JWT storage vulnerability and recommends HttpOnly cookies |
| P02: プロジェクト削除APIにおける権限チェックの曖昧性 | × | 0.0 | Section 2-11 mentions authorization model ambiguity but does not specifically call out the DELETE /api/v1/projects/:id permission gap |
| P03: ファイルアップロードにおけるファイル種別検証の欠如 | ○ | 1.0 | Section 1-4 explicitly identifies missing MIME type validation, magic byte checks, and malware scanning |
| P04: S3バケットのアクセス制御方針が不明確 | ○ | 1.0 | Section 1-4 mentions "アップロード後の S3 保存時のアクセス制御・暗号化設定が不明" and recommends signed URLs with expiration |
| P05: レート制限の具体的な設計が欠如 | ○ | 1.0 | Section 2-2 identifies missing rate limiting configuration with specific recommendations for tiered limits |
| P06: パスワードリセット機能の設計が存在しない | × | 0.0 | No mention of password reset or forgot password functionality |
| P07: 機密データの暗号化範囲が限定的 | ○ | 1.0 | Section 1-5 explicitly identifies missing encryption at rest for PostgreSQL and S3 beyond password hashing |
| P08: 外部サービス連携におけるOAuth2.0のスコープ管理方針が不明確 | ○ | 1.0 | Section 1-7 explicitly calls out missing OAuth 2.0 security design including scope management, token storage, and PKCE |
| P09: 監査ログ（Audit Log）の設計が欠如 | ○ | 1.0 | Section 1-6 explicitly identifies missing security audit logging for critical operations |

**Detection Score: 7.0**

### Bonus Points

| ID | Category | Justification | Score |
|----|----------|--------------|-------|
| B01 | 認証・認可設計 | Section 3-2 mentions "外部ユーザーにメール招待を送り、ゲストロールでアカウント作成" but does not recommend MFA | 0.0 |
| B02 | 認証・認可設計 | Section 1-2 explicitly recommends account lockout after 5 consecutive failures | +0.5 |
| B03 | データ保護 | Section 1-5 explicitly recommends AWS Secrets Manager for secrets management | +0.5 |
| B04 | 脅威モデリング | Section 1-4 explicitly identifies missing CSRF protection and recommends CSRF token validation | +0.5 |
| B05 | 入力検証設計 | Section 2-8 mentions "サニタイズエラーメッセージに機密データ(email addresses, IDs)を含めない" which relates to error message information disclosure | +0.5 |

**Bonus: +2.0**

### Penalty Points

| Description | Justification | Score |
|-------------|--------------|-------|
| None | All issues are within security-design scope | 0.0 |

**Penalty: 0**

**Run1 Total Score: 7.0 + 2.0 - 0 = 9.0**

---

## Run2 Detection Matrix

| Problem | Detection | Score | Evidence |
|---------|-----------|-------|----------|
| P01: JWTトークンのlocalStorage保存によるXSS脆弱性 | ○ | 1.0 | Section 1-1 explicitly identifies JWT localStorage vulnerability and recommends HttpOnly cookies |
| P02: プロジェクト削除APIにおける権限チェックの曖昧性 | × | 0.0 | Section 2-11 mentions authorization model details missing but does not specifically call out DELETE endpoint permission gaps |
| P03: ファイルアップロードにおけるファイル種別検証の欠如 | ○ | 1.0 | Section 1-3 explicitly identifies missing file type validation, MIME type verification, and malware scanning |
| P04: S3バケットのアクセス制御方針が不明確 | △ | 0.5 | Section 1-3 mentions "No access control for viewing uploaded files" and recommends "signed URLs with expiration" but primarily focuses on file upload security rather than S3 bucket access control policy |
| P05: レート制限の具体的な設計が欠如 | ○ | 1.0 | Section 2-2 explicitly identifies missing rate limiting specifications with specific recommendations |
| P06: パスワードリセット機能の設計が存在しない | × | 0.0 | No mention of password reset or forgot password functionality |
| P07: 機密データの暗号化範囲が限定的 | ○ | 1.0 | Section 1-7 explicitly identifies missing encryption at rest for PostgreSQL and S3 |
| P08: 外部サービス連携におけるOAuth2.0のスコープ管理方針が不明確 | × | 0.0 | No specific mention of OAuth 2.0 scope management or token handling in the review |
| P09: 監査ログ（Audit Log）の設計が欠如 | ○ | 1.0 | Section 1-6 explicitly identifies missing audit logging design |

**Detection Score: 5.5**

### Bonus Points

| ID | Category | Justification | Score |
|----|----------|--------------|-------|
| B01 | 認証・認可設計 | No mention of MFA requirement | 0.0 |
| B02 | 認証・認可設計 | Section 1-2 explicitly recommends account lockout mechanism | +0.5 |
| B03 | データ保護 | Section 1-5 explicitly recommends AWS Secrets Manager or Systems Manager Parameter Store | +0.5 |
| B04 | 脅威モデリング | Section 1-3 explicitly identifies missing CSRF protection and recommends implementation | +0.5 |
| B05 | 入力検証設計 | Section 2-3 mentions validation error detail risks but does not explicitly call out information disclosure via error messages | 0.0 |

**Bonus: +1.5**

### Penalty Points

| Description | Justification | Score |
|-------------|--------------|-------|
| None | All issues are within security-design scope | 0.0 |

**Penalty: 0**

**Run2 Total Score: 5.5 + 1.5 - 0 = 7.0**

---

## Summary

| Metric | Run1 | Run2 |
|--------|------|------|
| Detection Score | 7.0 | 5.5 |
| Bonus | +2.0 | +1.5 |
| Penalty | 0 | 0 |
| **Total** | **9.0** | **7.0** |
| **Mean** | **8.0** | |
| **Standard Deviation** | **1.0** | |

---

## Key Differences

**Run1 strengths:**
- Detected P04 (S3 access control) fully with explicit mention of access control and encryption settings
- Detected P08 (OAuth 2.0 scope management) with dedicated section 1-7

**Run2 weaknesses:**
- P04 detected only partially - focused on file upload security but less explicit on S3 bucket-level access control policy
- P08 completely missed - no mention of OAuth 2.0 security design
- Fewer bonus points due to missing B05 (error message information disclosure)

**Consistency:** SD = 1.0 indicates medium stability. The variance primarily stems from P04 partial detection and P08 miss in Run2.
