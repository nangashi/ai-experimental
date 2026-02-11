# Security Design Review: TravelHub システム設計書

## Executive Summary

This security evaluation identifies **4 critical issues**, **6 significant issues**, and **5 moderate issues** in the TravelHub design document. The most severe concerns include the use of localStorage for JWT storage (XSS vulnerability), missing CSRF protection, absence of rate limiting, and inadequate input validation policies.

## Overall Security Scores

| Evaluation Criterion | Score | Justification |
|---------------------|-------|---------------|
| Threat Modeling (STRIDE) | 2 | Multiple STRIDE threats inadequately addressed: Spoofing (weak JWT storage), Tampering (no CSRF), Repudiation (audit logging gaps), DoS (no rate limiting) |
| Authentication & Authorization Design | 2 | Critical flaw: JWT stored in localStorage is vulnerable to XSS attacks. Missing session management and token refresh policies |
| Data Protection | 3 | Encryption at rest mentioned but lacks key management, data classification, and retention policies |
| Input Validation Design | 2 | No validation policy defined. Missing sanitization strategies, injection prevention, and output escaping specifications |
| Infrastructure & Dependency Security | 3 | Basic infrastructure mentioned but lacks secret management, dependency vulnerability scanning, and network security details |

**Overall Assessment**: The design requires immediate security improvements before production deployment. Critical authentication flaws and missing security controls pose severe risks of data breach and account compromise.

---

## Critical Issues (Score 1-2)

### 1. [CRITICAL] JWT Storage in localStorage - XSS Vulnerability

**Severity**: 1/5 (Critical)
**Category**: Authentication & Authorization Design, Missing JWT/Token Storage Security
**Reference**: Section 5 - API設計 > 認証・認可方式, Line 187

**Issue**:
The design explicitly states "フロントエンドはlocalStorageにトークンを保存" (Frontend stores tokens in localStorage). This is a critical security vulnerability.

**Impact**:
- **XSS Attack Vector**: Any XSS vulnerability in the frontend (React/Next.js) application allows attackers to steal JWT tokens via JavaScript access to localStorage
- **Session Hijacking**: Stolen tokens enable attackers to impersonate users for 24 hours (token validity period)
- **Data Breach**: Attackers gain access to personal information, booking history, and payment details
- **Scope**: Affects all users of the platform

**Why This is Dangerous**:
- localStorage is accessible by any JavaScript code running in the same origin
- Modern web applications frequently have XSS vulnerabilities through third-party dependencies, user-generated content, or injection flaws
- Once a token is stolen, there is no way to detect or prevent its misuse until expiration
- The 24-hour token validity period provides a wide attack window

**Countermeasures**:
1. **Immediate Action**: Change JWT storage mechanism to httpOnly cookies with Secure flag
   ```
   Set-Cookie: access_token=<JWT>; HttpOnly; Secure; SameSite=Strict; Max-Age=86400
   ```
2. **Cookie Attributes**:
   - `HttpOnly`: Prevents JavaScript access to the token
   - `Secure`: Ensures transmission only over HTTPS
   - `SameSite=Strict`: Provides basic CSRF protection
3. **Token Refresh Design**: Implement short-lived access tokens (15 minutes) with refresh tokens stored in httpOnly cookies
4. **Backend Changes**: Update API Gateway/Backend to read JWT from Cookie header instead of Authorization header
5. **Frontend Changes**: Remove localStorage usage; cookies are automatically sent with requests

**Design Specification to Add**:
```markdown
### 認証・認可方式
- JWT（JSON Web Token）を使用
- アクセストークン有効期限: 15分
- リフレッシュトークン有効期限: 7日間
- トークン保存方式: httpOnly cookies (Secure, SameSite=Strict)
- トークンリフレッシュエンドポイント: POST /api/auth/refresh
```

---

### 2. [CRITICAL] Missing CSRF Protection

**Severity**: 1/5 (Critical)
**Category**: Missing CSRF/XSS Protection
**Reference**: Section 5 - API設計 (全体)

**Issue**:
The design document does not mention CSRF (Cross-Site Request Forgery) protection mechanisms for state-changing operations.

**Impact**:
- **Account Takeover**: Attackers can trick authenticated users into changing email/password via malicious sites
- **Unauthorized Bookings**: Attackers can create bookings on behalf of victims
- **Financial Loss**: Attackers can initiate payments or refunds without user consent
- **Data Modification**: User profiles, reviews, and booking information can be manipulated

**Why This is Dangerous**:
- All POST/PUT/DELETE operations are vulnerable: `/api/bookings`, `/api/payments`, `/api/reviews`, `/api/auth/password-reset`
- The current design using Bearer tokens in Authorization headers provides no CSRF protection if migrated to cookies (as recommended above)
- Users visiting malicious websites while authenticated are at risk

**Countermeasures**:
1. **CSRF Token Implementation**:
   - Generate CSRF tokens server-side and include in page responses
   - Frontend includes CSRF token in `X-CSRF-Token` header for state-changing requests
   - Backend validates token presence and correctness before processing
2. **Cookie SameSite Attribute**: Use `SameSite=Strict` or `SameSite=Lax` on authentication cookies
3. **Double Submit Cookie Pattern** (alternative):
   - Set CSRF token in both cookie and request header
   - Backend verifies both values match
4. **State-Changing Operations Validation**:
   - Require re-authentication for sensitive operations (password change, payment)
   - Implement confirmation steps for high-risk actions

**Design Specification to Add**:
```markdown
### CSRF Protection
- すべての状態変更操作（POST/PUT/DELETE）にCSRFトークン検証を適用
- CSRFトークンは`X-CSRF-Token`ヘッダーで送信
- トークン生成: サーバー側でランダム生成、セッションに紐付け
- トークン有効期限: セッション有効期間と同一
- CSRFトークン取得エンドポイント: GET /api/auth/csrf-token
```

---

### 3. [CRITICAL] Missing Rate Limiting and DoS Protection

**Severity**: 1/5 (Critical)
**Category**: Missing Rate Limiting/DoS Protection
**Reference**: Section 5 - API設計 (全体)

**Issue**:
The design document does not specify rate limiting, brute-force protection, or DoS mitigation strategies for any API endpoints.

**Impact**:
- **Credential Stuffing**: Attackers can attempt unlimited login attempts to compromise accounts
- **Service Degradation**: Excessive API calls can overwhelm backend services and degrade performance for legitimate users
- **Financial Loss**: Uncontrolled search API calls to external supplier APIs incur costs
- **Resource Exhaustion**: Database connection pool (50 connections) can be exhausted by attack traffic

**Why This is Dangerous**:
- Performance target mentions 1000 req/sec for search API but no mechanism to prevent abuse
- Login endpoint (`POST /api/auth/login`) is vulnerable to brute-force password guessing
- Password reset endpoint (`POST /api/auth/password-reset`) can be abused to send spam emails
- Payment endpoints lack protection against retry attacks

**Countermeasures**:
1. **API Gateway Rate Limiting**:
   - Implement rate limiting at AWS ALB level
   - Per-IP limits: 100 requests/minute for unauthenticated users
   - Per-user limits: 500 requests/minute for authenticated users
2. **Authentication Endpoint Protection**:
   - Login: 5 failed attempts per 15 minutes per IP/email, then temporary lock
   - Password reset: 3 requests per hour per email
   - Account lock after 10 failed login attempts (24-hour lock)
3. **Search API Throttling**:
   - 50 searches per hour per authenticated user
   - 10 searches per hour per unauthenticated IP
4. **Payment Endpoint Protection**:
   - 5 payment attempts per 10 minutes per user
   - Idempotency keys required (see separate issue below)
5. **Backend Service Protection**:
   - Implement circuit breakers for external supplier API calls
   - Queue-based request processing for non-critical operations

**Design Specification to Add**:
```markdown
### Rate Limiting & DoS Protection
- API Gatewayレベルでのレート制限:
  - 未認証: 100 req/min per IP
  - 認証済: 500 req/min per user
- 認証エンドポイント:
  - ログイン: 5回失敗で15分間ロック (per IP/email)
  - パスワードリセット: 3回/時間 per email
  - アカウントロック: 10回失敗で24時間ロック
- 検索API: 50回/時間 per user (認証済)、10回/時間 per IP (未認証)
- 決済API: 5回/10分 per user
- サーキットブレーカー: 外部API呼び出しに適用 (failure threshold: 50%, timeout: 30s)
```

---

### 4. [CRITICAL] Missing Input Validation Policy

**Severity**: 2/5 (Significant)
**Category**: Input Validation Design
**Reference**: Section 6 - 実装方針 (entire section lacks validation design)

**Issue**:
The design document does not define input validation policies, sanitization strategies, or injection prevention measures. Only mentions "Hibernate Validator" as a library without specifying validation rules.

**Impact**:
- **SQL Injection**: Query parameters in search/booking APIs may be vulnerable if not properly parameterized
- **NoSQL Injection**: JSONB field `booking_details` in bookings table is vulnerable to MongoDB-style injection if using dynamic queries
- **XSS Injection**: User-generated content in reviews and user profiles can contain malicious scripts
- **Command Injection**: File upload features (if implemented) may allow arbitrary command execution
- **Business Logic Bypass**: Missing validation on price fields, booking quantities, date ranges enables fraud

**Why This is Dangerous**:
- Multiple user input points exist: search parameters, booking details, review comments, profile information
- JSONB field in database (`booking_details`) requires special validation handling
- Elasticsearch queries are vulnerable to injection if constructed from user input
- External supplier API integration may pass unvalidated input to third parties

**Countermeasures**:
1. **Input Validation Policy**:
   - Whitelist validation: Define allowed characters, formats, and ranges for each input field
   - Reject invalid input with 400 Bad Request (do not attempt to sanitize)
2. **Specific Validation Rules**:
   - Email: RFC 5322 format validation
   - Phone: E.164 international format
   - Dates: ISO 8601 format, validate future dates for bookings, past dates for reviews
   - Amounts: Positive decimal, max 10 digits, max 2 decimal places
   - Rating: Integer 1-5 (already in schema, enforce at API level)
   - Text fields: Max length enforcement, no control characters
3. **Injection Prevention**:
   - SQL: Use parameterized queries exclusively (JPA/Hibernate default)
   - NoSQL: Validate JSONB structure before storage, use prepared statements for Elasticsearch
   - XSS: HTML entity encoding for all user-generated content before display
   - Command: Avoid shell execution; if necessary, whitelist allowed commands
4. **File Upload Validation** (if feature exists):
   - File type whitelist (magic number verification, not extension)
   - File size limit: 5MB
   - Virus scanning integration
   - Store in isolated storage (S3) with restrictive access policies
5. **API-Level Validation**:
   - Validate Content-Type header matches payload
   - Enforce request size limits
   - Validate JSONB field structure against schema before database insertion

**Design Specification to Add**:
```markdown
### Input Validation Policy
- 検証方式: ホワイトリスト検証を優先、不正入力は拒否
- 検証タイミング: APIレイヤーで最初に実行
- 検証ルール:
  - email: RFC 5322準拠、最大255文字
  - phone: E.164形式、最大20文字
  - 日付: ISO 8601形式、予約日は未来、レビュー日は過去
  - 金額: 正の数、最大10桁、小数点以下2桁
  - rating: 1-5の整数
  - テキスト: 最大長制限、制御文字禁止
- SQLインジェクション対策: パラメータ化クエリ使用
- XSS対策: HTMLエンティティエンコーディング適用
- JSONB検証: スキーマ検証後にデータベース挿入
- ファイルアップロード: MIME type検証、5MB制限、ウイルススキャン
```

---

## Significant Issues (Score 2)

### 5. [HIGH] Missing Idempotency Guarantees for State-Changing Operations

**Severity**: 2/5 (Significant)
**Category**: Missing Idempotency Guarantees
**Reference**: Section 5 - API設計 - 予約エンドポイント, 決済エンドポイント

**Issue**:
The design does not specify idempotency mechanisms for critical state-changing operations such as booking creation and payment processing.

**Impact**:
- **Double Booking**: Network retries or user double-clicks can create duplicate bookings
- **Double Charging**: Payment requests may be processed multiple times, charging users repeatedly
- **Data Inconsistency**: Duplicate records in bookings and payments tables
- **Financial Loss**: Refund processing and reconciliation overhead

**Why This is Dangerous**:
- Payment integration with Stripe is inherently stateful and irreversible
- Frontend JavaScript may retry failed requests automatically
- Network timeouts may cause users to resubmit requests
- Distributed system design (multiple Backend Services) increases retry likelihood

**Countermeasures**:
1. **Idempotency Key Design**:
   - Require `Idempotency-Key` header for POST/PUT/DELETE operations on bookings and payments
   - Key format: UUID v4 generated client-side
   - Backend stores key with operation result for 24 hours
   - Return cached response if duplicate key detected
2. **Specific Implementations**:
   - `POST /api/bookings`: Require `Idempotency-Key`, store in Redis with booking result
   - `POST /api/payments`: Require `Idempotency-Key`, use Stripe's idempotency key feature
   - `POST /api/payments/:id/refund`: Require `Idempotency-Key`, prevent duplicate refunds
3. **Duplicate Detection**:
   - Database unique constraints on `booking_reference` (already present) and `stripe_payment_id`
   - Check for in-flight operations before processing new requests
4. **User Experience**:
   - Disable submit buttons after first click
   - Show loading state during processing
   - Display clear success/error messages

**Design Specification to Add**:
```markdown
### Idempotency Design
- 状態変更操作に`Idempotency-Key`ヘッダーを必須化:
  - POST /api/bookings
  - POST /api/payments
  - POST /api/payments/:id/refund
- キー形式: UUID v4 (クライアント生成)
- キー保存: Redis, 24時間保持
- 重複検知: キーが既存の場合、キャッシュされた結果を返却
- Stripe連携: Stripeのidempotency key機能を使用
- データベース制約: booking_reference, stripe_payment_id にUNIQUE制約
```

---

### 6. [HIGH] Missing Audit Logging for Security-Critical Events

**Severity**: 2/5 (Significant)
**Category**: Missing Audit Logging
**Reference**: Section 6 - 実装方針 - ロギング方針

**Issue**:
The logging policy mentions "すべてのAPIリクエスト/レスポンスをログ出力" but does not specify:
- Which security-critical events require audit logging
- Log retention policies
- Log protection mechanisms
- PII/sensitive data masking policies

**Impact**:
- **Compliance Violations**: Unable to meet audit requirements for payment processing (PCI-DSS) and personal data handling (GDPR/個人情報保護法)
- **Incident Response Delays**: Insufficient logging hinders security incident investigation
- **Privacy Violations**: Logging sensitive data (passwords, credit card numbers) without masking exposes user data
- **Evidence Loss**: Short retention periods or lack of log protection prevents forensic analysis

**Why This is Dangerous**:
- Payment processing requires detailed audit trails for compliance
- Authentication failures and authorization bypasses must be logged for threat detection
- Current logging policy may inadvertently log sensitive data in API request/response logs

**Countermeasures**:
1. **Audit Event Categories**:
   - Authentication events: login success/failure, logout, password change, account lock
   - Authorization events: access denied, privilege escalation attempts
   - Data access: booking views, payment history access, PII access
   - Data modification: booking creation/modification/cancellation, payment/refund, profile changes
   - Administrative actions: user role changes, configuration updates
2. **Audit Log Content**:
   - Timestamp (UTC), event type, user ID, IP address, user agent
   - Request ID for correlation
   - Success/failure status, error codes
   - Affected resource IDs (booking ID, payment ID)
3. **Sensitive Data Masking**:
   - Passwords: Never log (even hashed)
   - Credit card numbers: Log only last 4 digits
   - Email addresses: Log hashed version for correlation
   - Phone numbers: Mask middle digits
   - Full name: Log only for admin-level audit logs
4. **Log Retention**:
   - Security audit logs: 2 years minimum (compliance requirement)
   - API request/response logs: 90 days
   - Error logs: 1 year
5. **Log Protection**:
   - Store logs in tamper-proof storage (AWS CloudWatch Logs with retention lock)
   - Implement log integrity verification (checksums)
   - Restrict log access to security team and auditors only
   - Monitor for log deletion attempts

**Design Specification to Add**:
```markdown
### Audit Logging Design
- 監査対象イベント:
  - 認証: ログイン成功/失敗、ログアウト、パスワード変更、アカウントロック
  - 認可: アクセス拒否、権限昇格試行
  - データアクセス: 予約閲覧、決済履歴閲覧、個人情報アクセス
  - データ変更: 予約作成/変更/キャンセル、決済/返金、プロフィール変更
  - 管理操作: ロール変更、設定更新
- ログ内容: タイムスタンプ(UTC)、イベント種別、ユーザーID、IPアドレス、リクエストID、成否、リソースID
- センシティブデータマスキング:
  - パスワード: ログ出力禁止
  - クレジットカード番号: 下4桁のみ
  - メールアドレス: ハッシュ化
  - 電話番号: 中間桁マスキング
- ログ保持期間:
  - セキュリティ監査ログ: 2年
  - APIリクエスト/レスポンスログ: 90日
  - エラーログ: 1年
- ログ保護: AWS CloudWatch Logs、改ざん防止設定、アクセス制限
```

---

### 7. [HIGH] Missing Token Refresh and Session Management

**Severity**: 2/5 (Significant)
**Category**: Authentication & Authorization Design
**Reference**: Section 5 - API設計 - 認証・認可方式

**Issue**:
The design specifies a 24-hour JWT validity period but does not mention:
- Token refresh mechanism
- Session management
- Token revocation strategy
- Logout implementation

**Impact**:
- **Long-Lived Tokens**: 24-hour validity provides a wide attack window if token is compromised
- **Inability to Revoke**: JWT tokens cannot be invalidated before expiration (stateless design)
- **Logout Ineffective**: Current logout endpoint (`POST /api/auth/logout`) cannot actually invalidate JWT tokens
- **Account Compromise**: Stolen tokens remain valid for 24 hours even after user detects breach

**Why This is Dangerous**:
- Stateless JWT design makes revocation impossible without additional infrastructure
- Users expect logout to immediately terminate their session
- No mechanism to respond to security incidents (e.g., "logout all sessions" after password change)

**Countermeasures**:
1. **Token Refresh Design**:
   - Short-lived access tokens: 15 minutes validity
   - Long-lived refresh tokens: 7 days validity, stored in httpOnly cookie
   - Refresh endpoint: `POST /api/auth/refresh` validates refresh token and issues new access token
2. **Token Revocation**:
   - Maintain token revocation list in Redis (store JTI claim)
   - Check revocation list on each authenticated request
   - Revoke all refresh tokens on password change
3. **Logout Implementation**:
   - Add JTI (JWT ID) to access token
   - On logout, add JTI to revocation list (TTL = token expiration time)
   - Clear authentication cookies
4. **Session Management**:
   - Track active sessions per user (store refresh token IDs in database)
   - Provide "active sessions" page for users to view and revoke devices
   - Implement "logout all sessions" functionality
5. **Security Incident Response**:
   - Admin API to revoke all tokens for a specific user
   - Mass revocation capability for security incidents

**Design Specification to Add**:
```markdown
### Token & Session Management
- アクセストークン有効期限: 15分
- リフレッシュトークン有効期限: 7日
- トークンリフレッシュ: POST /api/auth/refresh
- トークンリボケーション:
  - Redisでリボケーションリスト管理 (JTI claim使用)
  - ログアウト時、パスワード変更時にリボケーション
  - 認証リクエストごとにリボケーションチェック
- セッション管理:
  - ユーザーごとのアクティブセッション追跡 (データベース)
  - セッション一覧表示機能: GET /api/auth/sessions
  - セッション削除機能: DELETE /api/auth/sessions/:id
  - 全セッション削除: POST /api/auth/logout-all
- 管理API:
  - 特定ユーザーの全トークン無効化: POST /api/admin/users/:id/revoke-tokens
```

---

### 8. [HIGH] Missing Authorization Model Details

**Severity**: 2/5 (Significant)
**Category**: Authentication & Authorization Design
**Reference**: Section 5 - API設計 - 認証・認可方式, Line 189

**Issue**:
The design mentions "管理者APIは追加でロールベースアクセス制御（RBAC）を適用" but does not specify:
- Role definitions
- Permission assignments
- How roles are assigned and managed
- Which APIs require which roles

**Impact**:
- **Privilege Escalation**: Unclear authorization logic leads to implementation errors allowing unauthorized access
- **Data Breach**: Users may access other users' booking and payment information
- **Business Logic Bypass**: Corporate account features may be accessible to regular users
- **Inconsistent Enforcement**: Without clear specifications, different services may implement authorization differently

**Why This is Dangerous**:
- User Service manages "ビジネスアカウント" vs. regular accounts, but authorization model is undefined
- Booking and payment APIs must enforce user-specific access (users should only see their own bookings)
- Corporate administrators need special permissions for employee management
- Admin APIs are mentioned but not defined in the API design section

**Countermeasures**:
1. **Role Definition**:
   ```
   - guest: Unauthenticated user (search only)
   - user: Regular authenticated user (bookings, payments, reviews)
   - business_user: Business account user (same as user + travel points)
   - corporate_admin: Corporate administrator (manage employees, view corporate bookings)
   - platform_admin: Platform administrator (user management, system configuration)
   ```
2. **Permission Model**:
   - Resource-based access control: Users can only access their own bookings/payments/reviews
   - Ownership check: `GET /api/bookings/:id` verifies `booking.user_id == authenticated_user_id`
   - Corporate scope: Corporate admins can access bookings where `booking.user_id IN (employee_ids)`
3. **API Authorization Matrix**:
   ```
   GET /api/bookings/:id → guest: deny, user: owner only, corporate_admin: employee bookings only, platform_admin: all
   POST /api/bookings → guest: deny, user: allow, corporate_admin: allow, platform_admin: allow
   DELETE /api/bookings/:id → guest: deny, user: owner only, corporate_admin: deny, platform_admin: owner only
   ```
4. **Role Assignment**:
   - Add `role` column to `users` table (VARCHAR(20), default: 'user')
   - Add `corporate_id` column for business users (FOREIGN KEY to corporate accounts table)
   - Role changes require platform_admin permission
5. **Implementation Guidelines**:
   - Centralized authorization service or middleware
   - Annotations/decorators for permission checks: `@RequiresRole("user")`, `@RequiresOwnership("booking")`
   - Fail-safe defaults: deny access if authorization unclear

**Design Specification to Add**:
```markdown
### Authorization Model
- ロール定義:
  - guest: 未認証ユーザー (検索のみ)
  - user: 一般ユーザー (予約、決済、レビュー)
  - business_user: ビジネスアカウントユーザー (user権限 + ポイント機能)
  - corporate_admin: 企業管理者 (社員管理、企業予約閲覧)
  - platform_admin: プラットフォーム管理者 (ユーザー管理、システム設定)
- リソースベースアクセス制御:
  - 予約/決済/レビュー: ユーザーは自身のリソースのみアクセス可
  - 企業管理者: 所属企業の社員リソースにアクセス可
  - プラットフォーム管理者: 全リソースにアクセス可
- ロール管理:
  - usersテーブルにroleカラム追加 (VARCHAR(20), default: 'user')
  - ビジネスユーザーはcorporate_idカラムで企業に紐付け
  - ロール変更はplatform_admin権限が必要
- 実装: 集約的な認可サービス、アノテーションベースの権限チェック
```

---

### 9. [HIGH] Insufficient Error Handling Design

**Severity**: 2/5 (Significant)
**Category**: Missing Error Handling Design
**Reference**: Section 6 - 実装方針 - エラーハンドリング方針

**Issue**:
The error handling policy is incomplete. It mentions "ユーザー向けエラーメッセージとログ出力を分離" and "500エラー発生時はエラーIDを発行" but does not specify:
- What information to expose in error responses
- How to handle different error types (validation, authentication, business logic, system errors)
- Error response format
- Failover behavior for external dependencies

**Impact**:
- **Information Disclosure**: Verbose error messages may leak sensitive information (database structure, internal paths, library versions)
- **Poor User Experience**: Generic errors provide no guidance for users to resolve issues
- **Security Incident Masking**: System errors may hide security events (failed authorization should be logged differently than failed validation)
- **Service Degradation**: No failover strategy for external supplier API failures

**Why This is Dangerous**:
- External supplier API integration (Search Service) may fail unpredictably
- Payment processing errors require careful handling to avoid exposing Stripe internal errors
- Authentication errors must be handled carefully to avoid account enumeration
- Database errors may expose schema information in stack traces

**Countermeasures**:
1. **Error Response Format**:
   ```json
   {
     "error": {
       "code": "BOOKING_NOT_FOUND",
       "message": "指定された予約が見つかりません",
       "error_id": "550e8400-e29b-41d4-a716-446655440000",
       "timestamp": "2026-02-10T12:34:56Z"
     }
   }
   ```
2. **Error Categories and HTTP Status Codes**:
   - Validation errors: 400 Bad Request (expose field-level errors)
   - Authentication errors: 401 Unauthorized (generic message to prevent enumeration)
   - Authorization errors: 403 Forbidden (generic message, log details)
   - Not found: 404 Not Found (safe to expose)
   - Business logic errors: 422 Unprocessable Entity (expose user-actionable details)
   - Rate limit: 429 Too Many Requests (include Retry-After header)
   - System errors: 500 Internal Server Error (generic message, log full details with error_id)
3. **Information Exposure Policy**:
   - Never expose: Stack traces, internal paths, database queries, library versions
   - Always expose: Error codes, user-actionable messages, validation field errors
   - Conditionally expose: Business logic error details (only if user can resolve)
4. **External Dependency Failover**:
   - Supplier API timeout: Return cached results with staleness warning
   - Supplier API failure: Exclude failed supplier from results, log error
   - Payment gateway failure: Return 503 Service Unavailable with retry guidance
   - Database connection failure: Circuit breaker pattern, return 503
5. **Authentication Error Handling**:
   - Login failure: Always return same message regardless of whether email exists (prevent enumeration)
   - Token expiration: Return 401 with clear expiration message
   - Token validation failure: Return 401 with generic message, log details

**Design Specification to Add**:
```markdown
### Error Handling Design
- エラーレスポンス形式: JSON (error code, message, error_id, timestamp)
- HTTPステータスコード:
  - 400: バリデーションエラー (フィールド詳細を含む)
  - 401: 認証エラー (一般的メッセージのみ、列挙攻撃防止)
  - 403: 認可エラー (一般的メッセージ、詳細はログのみ)
  - 404: リソース未検出
  - 422: ビジネスロジックエラー (ユーザーが対処可能な詳細)
  - 429: レート制限 (Retry-Afterヘッダー含む)
  - 500: システムエラー (一般的メッセージ、error_idで追跡)
  - 503: 外部依存障害 (リトライガイダンス)
- 情報開示ポリシー:
  - 非開示: スタックトレース、内部パス、DBクエリ、ライブラリバージョン
  - 開示: エラーコード、ユーザー向けメッセージ、バリデーションエラー詳細
- 外部依存フェイルオーバー:
  - サプライヤーAPIタイムアウト: キャッシュ結果を返却 (staleness警告)
  - サプライヤーAPI障害: 障害サプライヤーを除外、ログ記録
  - 決済ゲートウェイ障害: 503を返却、リトライガイダンス提供
  - データベース接続障害: サーキットブレーカー、503返却
```

---

### 10. [HIGH] Missing Data Classification and Encryption Specifications

**Severity**: 2/5 (Significant)
**Category**: Data Protection
**Reference**: Section 7 - 非機能要件 - セキュリティ要件, Line 223-224

**Issue**:
The design mentions "個人情報の暗号化保存" but does not specify:
- Data classification scheme (what is considered sensitive)
- Which fields require encryption at rest
- Encryption algorithm and key management
- Encryption at rest implementation method (database-level, application-level, or field-level)

**Impact**:
- **Data Breach**: Unencrypted sensitive data in database backups or disk snapshots may be exposed
- **Compliance Violations**: GDPR and 個人情報保護法 require appropriate protection of personal data
- **Insider Threat**: Database administrators can access sensitive data without audit trail
- **Regulatory Penalties**: Failure to implement required data protection measures

**Why This is Dangerous**:
- Database contains highly sensitive data: passwords (hashed but sensitive), payment information, personal identifiers
- Current design mentions encryption but lacks implementation details
- PostgreSQL supports multiple encryption options (storage encryption, column encryption) but none are specified

**Countermeasures**:
1. **Data Classification**:
   - **Critical**: Passwords (hashed), payment methods, government IDs (if collected)
   - **High**: Full name, email, phone, booking details, payment amounts
   - **Medium**: Booking references, user preferences, travel history
   - **Low**: Public reviews, aggregated analytics data
2. **Encryption at Rest**:
   - Database storage encryption: Enable PostgreSQL transparent data encryption (TDE) or AWS RDS encryption
   - Application-level encryption for critical fields:
     - Payment method details (credit card last 4 digits, tokenized references)
     - Personal identifiers (if stored)
   - Key management: AWS KMS for encryption keys
   - Key rotation: Automatic annual rotation
3. **Encryption in Transit**:
   - All network communication uses TLS 1.3
   - Database connections use TLS (PostgreSQL SSL mode: require)
   - Inter-service communication uses mutual TLS (mTLS)
4. **Password Storage**:
   - Algorithm: Argon2id (not bcrypt or PBKDF2)
   - Parameters: Memory cost 64MB, time cost 3 iterations, parallelism 4
   - Salt: Random 128-bit per password
5. **Tokenization for Payment Data**:
   - Never store raw credit card numbers
   - Use Stripe's tokenization (store only token references)
   - Store only last 4 digits for user reference

**Design Specification to Add**:
```markdown
### Data Protection Design
- データ分類:
  - Critical: パスワード (hashed), 決済手段, 政府発行ID
  - High: 氏名, メールアドレス, 電話番号, 予約詳細, 決済金額
  - Medium: 予約番号, ユーザー設定, 旅行履歴
  - Low: 公開レビュー, 集計分析データ
- 暗号化 (at rest):
  - データベースストレージ暗号化: AWS RDS encryption有効化
  - アプリケーションレベル暗号化: 決済手段詳細、個人識別情報
  - キー管理: AWS KMS
  - キーローテーション: 年次自動ローテーション
- 暗号化 (in transit):
  - すべての通信: TLS 1.3
  - データベース接続: PostgreSQL SSL mode=require
  - サービス間通信: mutual TLS (mTLS)
- パスワード保存:
  - アルゴリズム: Argon2id
  - パラメータ: memory 64MB, time 3, parallelism 4
  - ソルト: ランダム128ビット per password
- 決済データ:
  - クレジットカード番号の生保存禁止
  - Stripe tokenization使用 (トークン参照のみ保存)
  - 下4桁のみユーザー参照用に保存
```

---

## Moderate Issues (Score 3)

### 11. [MEDIUM] Missing Data Retention and Deletion Policies

**Severity**: 3/5 (Moderate)
**Category**: Data Protection
**Reference**: Section 4 - データモデル (all tables lack retention policies)

**Issue**:
The design does not specify data retention periods or deletion policies for personal data and transactional records.

**Impact**:
- **GDPR Compliance**: GDPR requires defined retention periods and data deletion upon request
- **Storage Costs**: Unlimited data retention increases storage costs over time
- **Attack Surface**: Larger datasets provide more data for attackers to steal
- **Right to Erasure**: Unable to fulfill GDPR Article 17 "right to be forgotten" requests

**Countermeasures**:
1. **Retention Policies**:
   - User accounts: Retain until deletion request or 3 years of inactivity
   - Bookings: Retain for 7 years (tax/legal requirements)
   - Payments: Retain for 7 years (financial regulations)
   - Reviews: Retain indefinitely (business value) but anonymize author after account deletion
   - Audit logs: 2 years (compliance requirement)
2. **Deletion Policies**:
   - User deletion request: Anonymize user data (replace with "Deleted User"), delete PII
   - Transactional data: Retain booking/payment records for compliance, anonymize user linkage
   - Review anonymization: Replace user_id with NULL, keep review content
3. **Automated Deletion**:
   - Daily batch job to identify data past retention period
   - Soft delete with grace period (30 days) before hard delete
   - Audit logging of all deletion operations

**Design Specification to Add**:
```markdown
### Data Retention & Deletion Policies
- 保持期間:
  - ユーザーアカウント: 削除リクエストまたは3年間の非活動まで
  - 予約: 7年 (税務/法的要件)
  - 決済: 7年 (金融規制)
  - レビュー: 無期限 (アカウント削除時に著者を匿名化)
  - 監査ログ: 2年
- 削除ポリシー:
  - ユーザー削除リクエスト: 個人情報を匿名化 ("Deleted User")
  - 取引データ: 予約/決済記録は保持、ユーザー紐付けを匿名化
  - レビュー匿名化: user_idをNULLに置換、コンテンツは保持
- 自動削除: 日次バッチジョブ、30日間の猶予期間、削除操作を監査ログに記録
```

---

### 12. [MEDIUM] Missing Security Headers and Content Security Policy

**Severity**: 3/5 (Moderate)
**Category**: Missing CSRF/XSS Protection
**Reference**: Section 3 - アーキテクチャ設計 (frontend security not addressed)

**Issue**:
The design does not specify security headers or Content Security Policy (CSP) for the Next.js frontend application.

**Impact**:
- **XSS Attacks**: Missing CSP allows injected scripts to execute freely
- **Clickjacking**: Missing X-Frame-Options allows embedding site in malicious iframes
- **MIME Sniffing**: Missing X-Content-Type-Options allows browser to execute non-script content as scripts
- **Information Leakage**: Missing Referrer-Policy may leak sensitive URL parameters to third parties

**Countermeasures**:
1. **Content Security Policy**:
   ```
   Content-Security-Policy:
     default-src 'self';
     script-src 'self' 'unsafe-inline' https://js.stripe.com;
     style-src 'self' 'unsafe-inline';
     img-src 'self' data: https:;
     connect-src 'self' https://api.stripe.com;
     frame-src https://js.stripe.com;
     object-src 'none';
     base-uri 'self';
   ```
2. **Security Headers**:
   ```
   X-Frame-Options: DENY
   X-Content-Type-Options: nosniff
   Referrer-Policy: strict-origin-when-cross-origin
   Permissions-Policy: geolocation=(), camera=(), microphone=()
   Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
   ```
3. **Next.js Configuration**:
   - Configure headers in `next.config.js`
   - Use `@next/third-parties` for Stripe integration to avoid CSP violations
4. **Subresource Integrity (SRI)**:
   - Use SRI hashes for external scripts (Stripe SDK)
   - Verify script integrity before execution

**Design Specification to Add**:
```markdown
### Frontend Security Headers
- Content Security Policy: default-src 'self'; script-src 'self' https://js.stripe.com; など
- X-Frame-Options: DENY
- X-Content-Type-Options: nosniff
- Referrer-Policy: strict-origin-when-cross-origin
- Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
- Next.js設定: next.config.jsでheaders設定、Stripe統合は@next/third-parties使用
- Subresource Integrity: 外部スクリプトにSRIハッシュ適用
```

---

### 13. [MEDIUM] Missing Dependency Vulnerability Management

**Severity**: 3/5 (Moderate)
**Category**: Infrastructure & Dependency Security
**Reference**: Section 2 - 技術スタック (mentions libraries but no security scanning)

**Issue**:
The design lists multiple third-party libraries and frameworks but does not specify how to manage dependency vulnerabilities.

**Impact**:
- **Vulnerable Dependencies**: Known CVEs in libraries may be exploited (e.g., Log4Shell in Java ecosystems)
- **Supply Chain Attacks**: Compromised dependencies may introduce malicious code
- **Outdated Libraries**: Lack of update policy leads to accumulation of vulnerabilities
- **Incident Response**: No process to quickly patch critical vulnerabilities

**Countermeasures**:
1. **Dependency Scanning**:
   - Integrate Snyk or Dependabot into GitHub repository
   - Run vulnerability scans in CI/CD pipeline (fail build on high/critical vulnerabilities)
   - Scheduled weekly scans of production dependencies
2. **Dependency Update Policy**:
   - Security patches: Apply within 48 hours for critical, 7 days for high severity
   - Major version updates: Quarterly review and upgrade planning
   - Automated updates: Enable Dependabot auto-merge for patch-level updates
3. **Approved Dependency List**:
   - Maintain whitelist of approved libraries
   - Security review required for new dependencies
   - Prefer well-maintained libraries with active security response
4. **Software Bill of Materials (SBOM)**:
   - Generate SBOM during build process
   - Store SBOM for each production deployment
   - Use for vulnerability tracking and incident response
5. **Specific Risks**:
   - Stripe SDK: Subscribe to Stripe security advisories
   - jose/jjwt: JWT libraries frequently have vulnerabilities, prioritize updates
   - Spring Boot: Subscribe to Spring security advisories

**Design Specification to Add**:
```markdown
### Dependency Security Management
- 脆弱性スキャン:
  - CI/CDパイプラインにSnyk統合 (high/critical脆弱性でビルド失敗)
  - 本番依存関係の週次スキャン
- 更新ポリシー:
  - セキュリティパッチ: Critical 48時間以内, High 7日以内
  - メジャーバージョン更新: 四半期レビュー
  - 自動更新: Dependabot auto-merge (patch-levelのみ)
- 承認済み依存関係リスト:
  - 新規依存関係は セキュリティレビュー必須
  - メンテナンスが活発なライブラリを優先
- SBOM: ビルド時に生成、本番デプロイごとに保存
- 特定リスク:
  - Stripe SDK: セキュリティアドバイザリ購読
  - jose/jjwt: JWT library脆弱性に注意、優先更新
  - Spring Boot: Spring security advisories購読
```

---

### 14. [MEDIUM] Missing Secret Management Strategy

**Severity**: 3/5 (Moderate)
**Category**: Infrastructure & Dependency Security
**Reference**: Section 2 - 技術スタック, Section 3 - アーキテクチャ設計

**Issue**:
The design does not specify how to manage secrets (database credentials, API keys, Stripe keys, JWT signing keys).

**Impact**:
- **Credential Exposure**: Hardcoded secrets in code or environment variables may be leaked in version control or logs
- **Key Rotation Difficulty**: No process to rotate compromised credentials
- **Incident Response**: Unable to quickly revoke and rotate keys after security incident
- **Compliance**: Failure to protect secrets violates security best practices and compliance requirements

**Countermeasures**:
1. **Secret Storage**:
   - Use AWS Secrets Manager for all secrets
   - Never hardcode secrets in code or commit to version control
   - Environment variables loaded from Secrets Manager at runtime
2. **Secret Categories**:
   - Database credentials (PostgreSQL, Redis, Elasticsearch)
   - Stripe API keys (publishable and secret keys)
   - JWT signing key (HS256/RS256 private key)
   - External supplier API keys
   - AWS IAM access keys (if used)
3. **Secret Rotation**:
   - Automatic rotation for database credentials (90 days)
   - Manual rotation for API keys (annual or after security incident)
   - JWT signing key rotation: Monthly, with graceful transition (accept tokens signed by previous key for 1 hour)
4. **Access Control**:
   - IAM policies restrict secret access to specific services/roles
   - Least privilege: Backend services access only necessary secrets
   - Audit logging: All secret access logged to CloudTrail
5. **Development vs. Production**:
   - Separate secret sets for development, staging, production
   - Development secrets have no production access
   - Test data does not contain real credentials

**Design Specification to Add**:
```markdown
### Secret Management Strategy
- シークレット保存: AWS Secrets Manager
- シークレットカテゴリ:
  - データベース認証情報 (PostgreSQL, Redis, Elasticsearch)
  - Stripe APIキー (publishable, secret)
  - JWT署名鍵 (HS256/RS256 private key)
  - 外部サプライヤーAPIキー
- ローテーション:
  - データベース認証情報: 90日ごとに自動ローテーション
  - APIキー: 年次または セキュリティインシデント後に手動ローテーション
  - JWT署名鍵: 月次ローテーション、1時間の移行期間
- アクセス制御:
  - IAMポリシーでサービス/ロールごとに制限
  - 最小権限: 必要なシークレットのみアクセス
  - 監査ログ: CloudTrailにすべてのアクセスを記録
- 環境分離: 開発/ステージング/本番で別シークレットセット
```

---

### 15. [MEDIUM] Insufficient Network Security Specifications

**Severity**: 3/5 (Moderate)
**Category**: Infrastructure & Dependency Security
**Reference**: Section 7 - 非機能要件 - セキュリティ要件, Line 223

**Issue**:
The design mentions "データベース接続は専用のVPC内に閉じる" but lacks detailed network security specifications.

**Impact**:
- **Lateral Movement**: Compromised service may access other services without restrictions
- **Data Exfiltration**: Insufficient egress filtering allows attackers to send data to external servers
- **Attack Surface**: Publicly accessible services increase exposure to attacks
- **Compliance**: Inadequate network segmentation violates security best practices

**Countermeasures**:
1. **Network Segmentation**:
   - Public subnet: API Gateway (AWS ALB) only
   - Private subnet: Backend services (no direct internet access)
   - Database subnet: PostgreSQL, Redis, Elasticsearch (isolated, no internet access)
2. **Security Groups**:
   - ALB security group: Allow inbound 443 from 0.0.0.0/0
   - Backend services security group: Allow inbound only from ALB security group
   - Database security group: Allow inbound only from backend services security group
   - Deny all other traffic by default
3. **Network ACLs**:
   - Subnet-level restrictions as additional defense layer
   - Deny outbound to known malicious IPs (threat intelligence feeds)
4. **Egress Filtering**:
   - Backend services: Allow outbound to specific external APIs only (Stripe, supplier APIs)
   - Use NAT Gateway for controlled internet access
   - Deny direct database outbound connections
5. **Private Endpoints**:
   - Use VPC endpoints for AWS services (S3, Secrets Manager, CloudWatch)
   - Avoid public internet routing for AWS service communication

**Design Specification to Add**:
```markdown
### Network Security Design
- ネットワークセグメンテーション:
  - Public subnet: API Gateway (ALB) のみ
  - Private subnet: バックエンドサービス (インターネット直接アクセス不可)
  - Database subnet: PostgreSQL, Redis, Elasticsearch (隔離、インターネット不可)
- Security Groups:
  - ALB: 443 from 0.0.0.0/0
  - Backend: インバウンドはALBからのみ
  - Database: インバウンドはBackendからのみ
  - デフォルトdeny all
- Egress Filtering:
  - Backend: 特定外部API (Stripe, サプライヤーAPI) のみ許可
  - NAT Gateway経由で制御されたインターネットアクセス
  - データベースアウトバウンド接続拒否
- VPC Endpoints: AWS services (S3, Secrets Manager, CloudWatch) にVPCエンドポイント使用
```

---

## Positive Security Aspects

### Strengths Identified

1. **HTTPS Enforcement**: Design specifies HTTPS for all communication (Section 7, Line 222)
2. **Database Isolation**: VPC-based database isolation mentioned (Section 7, Line 223)
3. **Unique Constraints**: Proper use of UNIQUE constraints on `email`, `booking_reference` (Section 4)
4. **Multi-AZ Database**: High availability configuration mentioned (Section 7, Line 228)
5. **Error ID Tracking**: Error ID generation for traceability (Section 6, Line 196)
6. **Request ID Logging**: Request ID included in logs for correlation (Section 6, Line 201)
7. **Monitoring Integration**: Datadog monitoring mentioned (Section 2, Line 44)
8. **CI/CD Testing**: Automated testing before deployment (Section 6, Line 211)

---

## Infrastructure Security Assessment

| Component | Configuration | Security Measure | Status | Risk Level | Recommendation |
|-----------|---------------|------------------|--------|------------|----------------|
| PostgreSQL | Multi-AZ, VPC-isolated | Access control, encryption, backup | Partial | High | Add encryption at rest specification, credential rotation policy, connection TLS enforcement |
| Redis | Cache/session storage | Network isolation, authentication | Missing | High | Specify authentication method (requirepass), TLS encryption, data expiration policies |
| Elasticsearch | Search index | Network isolation, authentication | Missing | High | Specify authentication (X-Pack Security), TLS encryption, index access control, audit logging |
| API Gateway (ALB) | HTTPS endpoint | Authentication, rate limiting, CORS | Partial | Critical | Add rate limiting configuration, WAF integration, DDoS protection (AWS Shield) |
| Secrets Management | Not specified | Rotation, access control, storage | Missing | Critical | Implement AWS Secrets Manager, define rotation policies, IAM access control |
| Dependencies | Listed libraries | Version management, vulnerability scanning | Missing | High | Integrate Snyk/Dependabot, define update policies, generate SBOM |
| Kubernetes | Container orchestration | Pod security, network policies | Missing | High | Specify pod security policies, network policies, RBAC configuration, secret injection method |
| CI/CD (GitHub Actions) | Build/deploy pipeline | Secret handling, access control | Missing | Medium | Specify how secrets are injected, use GitHub Secrets, limit workflow permissions |

---

## Summary and Prioritized Recommendations

### Immediate Actions Required (Critical/High Severity)

1. **Change JWT storage from localStorage to httpOnly cookies** (Issue #1)
2. **Implement CSRF protection** for all state-changing operations (Issue #2)
3. **Add rate limiting** to API Gateway and authentication endpoints (Issue #3)
4. **Define input validation policy** and implement validation rules (Issue #4)
5. **Implement idempotency keys** for bookings and payments (Issue #5)
6. **Add audit logging** for security-critical events with proper masking (Issue #6)
7. **Design token refresh and session management** (Issue #7)
8. **Specify authorization model** with roles and permissions (Issue #8)

### Short-Term Actions (Within Sprint)

9. **Improve error handling design** with clear exposure policies (Issue #9)
10. **Add data encryption specifications** and key management (Issue #10)
11. **Define data retention and deletion policies** (Issue #11)
12. **Implement security headers and CSP** (Issue #12)
13. **Set up dependency vulnerability scanning** (Issue #13)

### Medium-Term Actions (Within Quarter)

14. **Implement secret management strategy** with AWS Secrets Manager (Issue #14)
15. **Specify network security details** with segmentation and egress filtering (Issue #15)

### Conclusion

The TravelHub design document demonstrates awareness of basic security requirements (HTTPS, VPC isolation) but lacks critical security specifications necessary for production deployment. The most severe issues—localStorage JWT storage, missing CSRF protection, and absence of rate limiting—pose immediate risks of account compromise and service abuse.

Implementing the recommended countermeasures, particularly the 8 immediate actions, is essential before launching the platform. The design should be updated to include explicit security specifications in each area, ensuring implementation teams have clear guidance.

**Overall Security Maturity**: The design is at an early stage of security maturity. With the recommended improvements, it can reach production-ready security standards.
