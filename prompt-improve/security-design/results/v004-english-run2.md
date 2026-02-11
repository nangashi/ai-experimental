# Security Design Review: Enterprise HR & Payroll Management System

## Score Summary

| Criterion | Score (1-5) | Main Reason |
|-----------|-------------|-------------|
| Threat Modeling (STRIDE) | 2 | Multiple STRIDE threats inadequately addressed: no session revocation (Spoofing), plaintext secrets enable tampering, insufficient audit logging (Repudiation), unencrypted sensitive data (Information Disclosure), no DoS protection, long-lived tokens enable privilege escalation |
| Authentication & Authorization Design | 2 | 24-hour JWT without refresh mechanism creates extended attack window; no session management or revocation capability; no MFA or account lockout protection |
| Data Protection | 1 | **CRITICAL**: Highly sensitive data (my_number, bank_account, salary_amount) stored in plaintext; plaintext secrets in environment variables; personal data logged without redaction |
| Input Validation Design | 3 | No input validation strategy documented; SQL injection risk mitigated by framework but no explicit validation policy; no file upload restrictions or size limits mentioned |
| Infrastructure & Dependencies | 2 | Secrets stored as plaintext environment variables; no dependency scanning or SBOM; specific library versions mentioned but no update policy; no network segmentation defined |
| **Overall** | **2.0** | |

---

## 1. Critical Issues (design modification required)

### 1.1 Highly Sensitive Data Stored Unencrypted in Database

**Problem**: Section 7.2 states "マイナンバー・口座番号はデータベースに保存（暗号化なし）" (My Number and bank account numbers stored in database without encryption). The `employees` table (Section 4.1) stores `my_number` (Japanese national ID) and `bank_account` in plaintext.

**Impact**:
- **Regulatory violation**: Japan's My Number Act (Act on the Use of Numbers) requires strict protection measures including encryption for stored My Number data. Non-compliance can result in criminal penalties (up to 4 years imprisonment or ¥2 million fine for business operators).
- **Data breach consequences**: If database is compromised (SQL injection, backup theft, insider threat), attackers gain immediate access to:
  - All employees' national ID numbers (enabling identity theft, tax fraud)
  - Bank account numbers (enabling unauthorized transfers if combined with other data)
  - Salary information (privacy violation, competitive intelligence)
- **Compliance failures**: GDPR Article 32 (if EU employees), APPI (Japan's Act on the Protection of Personal Information) require "appropriate security measures" for sensitive personal data.

**Recommended Countermeasures**:
1. **Implement application-level encryption for at-rest data**:
   - Use AES-256-GCM for encrypting `my_number`, `bank_account`, `salary_amount` columns
   - Store encryption keys in **AWS KMS** or **AWS Secrets Manager** with rotation policy (not environment variables)
   - Example: Use Spring Boot's `@ColumnTransformer` with JCE or Jasypt library (v1.9.3+) for transparent column encryption

2. **Database-level protection**:
   - Enable PostgreSQL TDE (Transparent Data Encryption) via AWS RDS encryption-at-rest
   - Use encrypted EBS volumes for RDS instances
   - Implement column-level encryption as primary defense, TDE as secondary layer

3. **Access control**:
   - Create separate database role with restricted permissions for application access (no direct access to encrypted columns without decryption key)
   - Implement audit logging for all My Number access (required by My Number Act)
   - Restrict decryption operations to specific service methods with audit trail

**Relevant Section**: Section 4.1 (Data Model - employees table), Section 7.2 (Security Requirements)

---

### 1.2 Secrets Stored as Plaintext in Environment Variables

**Problem**: Section 6.5 states "秘密情報(JWT署名鍵、データベースパスワード)は環境変数に平文で設定" (Secrets like JWT signing key and database password are stored as plaintext in environment variables).

**Impact**:
- **JWT signing key exposure**: If ECS task definition or container environment is compromised, attackers can:
  - Forge arbitrary JWT tokens with any tenant_id, user_id, or role
  - Impersonate HR_MANAGER or ADMIN users to access all tenant data
  - Create tokens with extended expiration times
- **Database credential exposure**: Compromised database password allows direct database access, bypassing all application-level security controls (Row-Level Security, audit logging)
- **Supply chain attack surface**: Environment variables visible in:
  - ECS task metadata endpoint (http://169.254.170.2/v2/metadata accessible from container)
  - CloudWatch Logs if accidentally logged
  - CI/CD pipeline logs (GitHub Actions)
  - Developer machines during local development

**Recommended Countermeasures**:
1. **Use AWS Secrets Manager for all secrets**:
   ```java
   // Replace environment variable reading with Secrets Manager SDK
   AWSSecretsManager client = AWSSecretsManagerClientBuilder.standard()
       .withRegion(Regions.AP_NORTHEAST_1).build();
   GetSecretValueRequest request = new GetSecretValueRequest()
       .withSecretId("prod/hr-system/jwt-signing-key");
   String jwtSecret = client.getSecretValue(request).getSecretString();
   ```
   - Store JWT signing key in Secrets Manager with automatic rotation (90 days)
   - Use RDS IAM authentication instead of password-based authentication

2. **ECS task execution improvements**:
   - Use `secrets` field in ECS task definition (not `environment`) to inject Secrets Manager values
   - Grant ECS task role `secretsmanager:GetSecretValue` permission via IAM policy
   - Enable automatic secret rotation with Lambda rotation function

3. **JWT signing key rotation strategy**:
   - Implement key versioning: Include `kid` (key ID) in JWT header
   - Support multiple active keys during rotation period (N and N-1)
   - Use asymmetric signing (RS256 with RSA-2048) instead of HMAC-SHA256 to separate signing/verification concerns

**Relevant Section**: Section 6.5 (Deployment Policy), Section 6.1 (Authentication Method)

---

### 1.3 Personal Information Logged Without Redaction

**Problem**: Section 6.3 states "個人情報(氏名、メール、給与額)はログに出力する" (Personal information including names, emails, and salary amounts are logged).

**Impact**:
- **Log aggregation security**: Datadog receives unredacted personal data, creating:
  - Third-party data processor compliance requirements (GDPR Article 28, APPI Article 23)
  - Expanded attack surface (Datadog account compromise exposes all employee data)
  - Data residency concerns (logs may be stored outside Japan)
- **Insider threat**: Engineers with Datadog access can query historical salary data, performance evaluations, and attendance records without business need
- **Compliance violations**:
  - GDPR Article 5(1)(c) - data minimization principle
  - APPI Article 20 - requirement to minimize personal data collection/use
  - My Number Act Article 20 - prohibition of My Number logging except for legally permitted purposes

**Recommended Countermeasures**:
1. **Implement structured logging with automatic PII redaction**:
   ```java
   // Use Logback with custom masking pattern
   log.info("Employee updated",
            "employee_id", employeeId,  // Keep ID for debugging
            "email_hash", hashEmail(email),  // Hash for correlation
            "salary", "[REDACTED]");
   ```
   - Create custom Logback converter to detect and redact PII fields (email, phone_number, full_name, salary_amount, my_number, bank_account)
   - Use SHA-256 hashes for correlation without exposing original values

2. **Separate audit logging from operational logging**:
   - Store audit logs (Section 6.3 requirements: authentication events, permission errors, salary calculations, employee updates) in **separate database table** with encryption and strict retention policy
   - Audit logs: Include user_id, action type, timestamp, affected entity IDs (not full personal data)
   - Operational logs: Only include non-PII technical data (request_id, latency, error codes)

3. **Datadog configuration hardening**:
   - Enable Datadog log scrubbing rules for known PII patterns (email regex, Japanese phone numbers)
   - Use Datadog RBAC to restrict log access to security team only
   - Configure log retention to 30 days maximum (not default 15 months)

**Relevant Section**: Section 6.3 (Logging Policy)

---

### 1.4 No Session Revocation Mechanism with Long-Lived Tokens

**Problem**: Section 6.1 states "リフレッシュトークンは発行せず、期限切れ時は再ログインを要求" (No refresh token issued; re-login required on expiration). JWT expiration is 24 hours (Section 3.3). JWTs are stateless with no server-side session management.

**Impact**:
- **Account compromise**: If employee is terminated or credentials are compromised:
  - Stolen JWT remains valid for up to 24 hours
  - No way to forcibly logout user or revoke access
  - HR cannot immediately revoke access when employee leaves company
- **Privilege escalation window**: If user role is downgraded (e.g., HR_MANAGER → EMPLOYEE), existing JWT with old role remains valid until expiration
- **Compliance risk**: Labor law requires immediate access revocation upon termination; 24-hour window violates this requirement

**Recommended Countermeasures**:
1. **Implement refresh token pattern with short-lived access tokens**:
   - **Access token**: 15-minute expiration, contains user_id, tenant_id, role
   - **Refresh token**: 7-day expiration, stored in Redis with user_id as key
     ```java
     // Refresh token structure in Redis
     Key: "refresh_token:{user_id}:{token_id}"
     Value: { tenant_id, issued_at, device_fingerprint }
     TTL: 7 days
     ```
   - Implement token rotation: Issue new refresh token on each refresh, invalidate old token

2. **Add server-side session tracking in Redis**:
   ```java
   // Active session tracking
   Key: "active_sessions:{user_id}"
   Value: Set of { token_id, issued_at, ip_address, user_agent }
   TTL: 24 hours
   ```
   - On JWT validation, check if `token_id` exists in active sessions set
   - Add `/api/auth/logout` endpoint to remove token from Redis
   - Add `/api/admin/revoke-sessions/{user_id}` for forced logout by HR

3. **Implement session management UI for users**:
   - Show active sessions with device info and login time
   - Allow users to revoke individual sessions
   - Automatic revocation on password change

**Relevant Section**: Section 3.3 (Data Flow), Section 6.1 (Authentication Method)

---

### 1.5 No Rate Limiting or Brute-Force Protection

**Problem**: No rate limiting is mentioned in API design (Section 5) or architecture (Section 3). The `/api/auth/login` endpoint (Section 5.1) has no protection against repeated login attempts.

**Impact**:
- **Brute-force attacks**: Attackers can attempt thousands of login combinations against `/api/auth/login` without restriction
- **Credential stuffing**: Leaked credentials from other breaches can be tested at scale
- **DoS attacks**: Expensive operations (e.g., `/api/payroll/calculate` triggers Spring Batch job for 1000 employees) can be repeatedly triggered by authenticated attackers
- **Resource exhaustion**: No protection against API abuse can cause:
  - Database connection pool exhaustion
  - ECS task CPU/memory saturation
  - Increased AWS costs from auto-scaling

**Recommended Countermeasures**:
1. **Implement layered rate limiting**:

   **Layer 1: ALB level (AWS WAF)**
   - IP-based rate limiting: 100 requests per 5 minutes per IP to `/api/auth/login`
   - Configure AWS WAF rate-based rule attached to ALB

   **Layer 2: Application level (Spring Boot)**
   ```java
   // Use Bucket4j library for token bucket algorithm
   @Configuration
   public class RateLimitConfig {
       @Bean
       public RateLimitInterceptor loginRateLimit() {
           // 5 attempts per 15 minutes per IP
           return RateLimitInterceptor.builder()
               .limit(5)
               .duration(Duration.ofMinutes(15))
               .keyExtractor(request -> request.getRemoteAddr())
               .build();
       }

       @Bean
       public RateLimitInterceptor apiRateLimit() {
           // 1000 requests per hour per user
           return RateLimitInterceptor.builder()
               .limit(1000)
               .duration(Duration.ofHours(1))
               .keyExtractor(request -> extractUserId(request))
               .build();
       }
   }
   ```

   **Layer 3: Account lockout**
   - After 5 failed login attempts within 15 minutes: Lock account for 30 minutes
   - Store lockout state in Redis: `Key: "account_lockout:{email}", TTL: 30 minutes`
   - Send email notification to user on lockout (potential attack indicator)

2. **Endpoint-specific limits**:
   - `/api/auth/login`: 5 attempts per 15 minutes per IP + account lockout
   - `/api/payroll/calculate`: 10 requests per hour per tenant (prevent batch job abuse)
   - `/api/employees` (POST/PUT/DELETE): 100 operations per hour per user
   - General authenticated APIs: 1000 requests per hour per user

3. **Monitoring and alerting**:
   - CloudWatch alarm on login failure rate > 100/minute
   - Datadog monitor for rate limit hit rate per endpoint
   - Automatic temporary IP ban (1 hour) via AWS WAF on excessive failures

**Relevant Section**: Section 5.1 (Authentication Endpoints), Section 3.1 (Architecture - ALB)

---

## 2. Improvement Suggestions (effective for improving design quality)

### 2.1 Input Validation Strategy Not Documented

**Suggestion**: No input validation policy is documented in Section 6 (Implementation Policy). While Spring Boot framework provides some protection, explicit validation strategy is missing.

**Rationale**:
- HR data has complex validation rules (Japanese postal codes, phone numbers, employee codes, My Number format check digit)
- Invalid data can cause downstream issues (payroll calculation errors, compliance violations)
- Defense-in-depth requires explicit validation layer separate from framework defaults

**Recommended Countermeasures**:
1. **Define validation policy in design document**:
   - Use Bean Validation (JSR 380) with custom validators
   - Example validations:
     ```java
     @MyNumberValid  // Custom validator for 12-digit + check digit
     private String myNumber;

     @Pattern(regexp = "E[0-9]{3}")
     private String employeeCode;

     @Email(regexp = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")
     private String email;

     @Min(0) @Max(100_000_000)  // Reasonable salary range
     private BigDecimal salaryAmount;
     ```

2. **Input sanitization strategy**:
   - Strip HTML tags from all text inputs (even though React escapes output, defense-in-depth)
   - Normalize Unicode characters (prevent homograph attacks in employee names)
   - Validate file uploads: MIME type check, file extension whitelist (.pdf, .jpg only), max size 10MB

3. **Database query parameterization**:
   - Document requirement to use Spring Data JPA with parameterized queries (already implied by framework but should be explicit policy)
   - Add static analysis rule (SpotBugs or Error Prone) to detect string concatenation in JPQL/native queries

**Relevant Section**: Section 6 (Implementation Policy - missing validation section)

---

### 2.2 Insufficient Audit Logging for Sensitive Operations

**Suggestion**: Section 6.3 mentions audit logging for "認証イベント、権限エラー、給与計算実行、従業員情報更新" (authentication events, permission errors, payroll calculations, employee updates), but lacks detail on what specific fields to log and retention requirements.

**Rationale**:
- Forensic investigations require detailed audit trail with immutable records
- Compliance requirements (APPI Article 25, My Number Act Article 20) mandate audit logs for personal data access
- Current design lacks clarity on:
  - What constitutes "employee information update" (all fields vs. sensitive fields only?)
  - Who accessed whose payroll data (especially for bulk operations)
  - Changes to user roles and permissions

**Recommended Countermeasures**:
1. **Define comprehensive audit event catalog**:

   | Event Type | Required Fields | Retention |
   |------------|----------------|-----------|
   | Authentication | user_id, tenant_id, ip_address, user_agent, success/failure, timestamp | 1 year |
   | Authorization Failure | user_id, requested_resource, required_role, actual_role, timestamp | 1 year |
   | Payroll Calculation | calculated_by, employee_ids (list), payroll_month, job_id, timestamp | 7 years (tax law) |
   | Employee Data Update | updated_by, employee_id, changed_fields (list), old_values (hashed), new_values (hashed), timestamp | 3 years |
   | My Number Access | accessed_by, employee_id, access_reason, timestamp | 7 years (My Number Act) |
   | Bulk Data Export | exported_by, record_count, export_type, timestamp | 1 year |
   | Role/Permission Change | changed_by, target_user_id, old_role, new_role, timestamp | 3 years |

2. **Implement append-only audit log table**:
   ```sql
   CREATE TABLE audit_logs (
       id UUID PRIMARY KEY,
       tenant_id UUID NOT NULL,
       event_type VARCHAR(50) NOT NULL,
       actor_user_id UUID NOT NULL,
       target_entity_type VARCHAR(50),
       target_entity_id UUID,
       event_data JSONB NOT NULL,  -- Structured event-specific fields
       ip_address INET,
       user_agent TEXT,
       created_at TIMESTAMP NOT NULL DEFAULT NOW()
   );
   CREATE INDEX idx_audit_tenant_time ON audit_logs(tenant_id, created_at DESC);
   CREATE INDEX idx_audit_actor ON audit_logs(actor_user_id, created_at DESC);
   -- Prevent updates/deletes via RLS policy
   ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
   CREATE POLICY audit_insert_only ON audit_logs FOR DELETE USING (false);
   CREATE POLICY audit_no_update ON audit_logs FOR UPDATE USING (false);
   ```

3. **Add audit log export API for compliance**:
   - `/api/admin/audit-logs/export` with date range filter
   - Restrict to ADMIN role only
   - Include this export action itself in audit log (meta-audit)

**Relevant Section**: Section 6.3 (Logging Policy)

---

### 2.3 No CSRF Protection Mechanism Documented

**Suggestion**: API design (Section 5) uses JWT in `Authorization` header, but no CSRF protection is mentioned. If JWT is also stored in cookies (not clear from design), CSRF attacks are possible.

**Rationale**:
- Section 3.3 shows JWT transmitted in `Authorization: Bearer <token>` header (safe from CSRF)
- However, authentication endpoint design doesn't specify where client should store JWT
- If developer implementation stores JWT in cookie for convenience, CSRF vulnerability is introduced
- State-changing operations (POST/PUT/DELETE) need CSRF protection if cookie-based authentication is used

**Recommended Countermeasures**:
1. **Explicitly document JWT storage requirement**:
   - Add to Section 6.1: "JWT must be stored in browser memory (React state) or sessionStorage, NOT in cookies or localStorage"
   - Rationale:
     - Cookies → CSRF risk
     - localStorage → XSS persistence risk (even after tab close)
     - Memory/sessionStorage → XSS risk limited to current session

2. **If cookie-based storage is chosen** (for UX reasons like SSO):
   - Implement Double Submit Cookie pattern:
     ```java
     // On login, issue two tokens
     Cookie jwtCookie = new Cookie("access_token", jwt);
     jwtCookie.setHttpOnly(true);
     jwtCookie.setSecure(true);
     jwtCookie.setSameSite("Strict");

     String csrfToken = generateSecureRandomToken();
     Cookie csrfCookie = new Cookie("csrf_token", csrfToken);
     csrfCookie.setHttpOnly(false);  // Readable by JavaScript
     csrfCookie.setSecure(true);
     csrfCookie.setSameSite("Strict");

     // Client must include CSRF token in X-CSRF-Token header
     // Server validates header value matches cookie value
     ```
   - Add Spring Security CSRF filter to validate token on all state-changing requests

3. **Add SameSite cookie attribute**:
   - If JWTs are in cookies, enforce `SameSite=Strict` to prevent cross-site request inclusion
   - Already provides strong CSRF protection for modern browsers

**Relevant Section**: Section 3.3 (Data Flow), Section 6.1 (Authentication Method)

---

### 2.4 Database Backup Strategy Lacks Security Controls

**Suggestion**: Section 7.3 states "データベースバックアップ: 日次フルバックアップ" (daily full backups) but doesn't mention backup security, encryption, or access controls.

**Rationale**:
- Database backups contain all sensitive data (My Numbers, salaries, personal information)
- Backup storage is often overlooked attack vector (weaker access controls than production database)
- If backup files are stolen, all historical data is compromised
- Compliance requires same protection level for backups as production data

**Recommended Countermeasures**:
1. **Enable RDS automated backup encryption**:
   - Use AWS KMS customer-managed key (not default AWS-managed key) for backup encryption
   - Enable "Encrypt backups" option in RDS configuration
   - Backups are encrypted with same key as RDS instance

2. **Backup access control**:
   - Store RDS snapshots in dedicated S3 bucket with:
     - S3 bucket encryption enabled (SSE-KMS)
     - Bucket policy denying public access
     - MFA Delete enabled
     - Versioning enabled (protect against accidental deletion)
   - Restrict `rds:RestoreDBInstanceFromDBSnapshot` IAM permission to senior engineering role only

3. **Backup retention and lifecycle**:
   - Daily automated backups: 30-day retention
   - Monthly manual snapshots: 7-year retention (for payroll compliance)
   - Implement S3 lifecycle policy to transition old snapshots to Glacier for cost optimization
   - Document backup restoration procedure and test quarterly (add to Section 6.5)

4. **Cross-region backup replication**:
   - Replicate critical snapshots to secondary AWS region (e.g., ap-southeast-1) for disaster recovery
   - Improves RTO/RPO beyond current 4 hours/24 hours targets

**Relevant Section**: Section 7.3 (Availability & Scalability)

---

### 2.5 No Dependency Vulnerability Management Process

**Suggestion**: Section 2.4 lists specific library versions (Spring Boot 3.2, Spring Security 6.2, etc.) but no process for tracking and updating vulnerable dependencies.

**Rationale**:
- Third-party libraries are common attack vector (e.g., Log4Shell, Spring4Shell)
- Apache PDFBox (Section 2.4) has had multiple CVEs related to XML parsing vulnerabilities
- RestTemplate is in maintenance mode (Spring recommends WebClient)
- Without systematic scanning, vulnerable dependencies remain in production for months

**Recommended Countermeasures**:
1. **Implement automated dependency scanning in CI/CD**:
   - Add OWASP Dependency-Check or Snyk to GitHub Actions pipeline
   - Example GitHub Actions step:
     ```yaml
     - name: Dependency Vulnerability Scan
       uses: dependency-check/Dependency-Check_Action@main
       with:
         project: 'hr-payroll-system'
         path: '.'
         format: 'JSON'
         failBuildOnCVSS: 7  # Fail build on High/Critical CVEs
     ```
   - Run on every PR and scheduled weekly scans

2. **Define dependency update policy**:
   - **Critical vulnerabilities (CVSS ≥ 9.0)**: Patch within 7 days
   - **High vulnerabilities (CVSS 7.0-8.9)**: Patch within 30 days
   - **Medium/Low**: Review quarterly
   - Document exceptions with risk acceptance approval from security team

3. **Generate and maintain Software Bill of Materials (SBOM)**:
   - Use CycloneDX Maven plugin to generate SBOM in CycloneDX format
   - Store SBOM with each release for vulnerability tracking and compliance
   - Required for upcoming EU Cyber Resilience Act compliance

4. **Replace deprecated libraries**:
   - Migrate from RestTemplate to WebClient (reactive, better connection pooling)
   - Review Apache PDFBox alternatives (e.g., OpenPDF, iText) if PDF generation doesn't need full PDF editing capabilities

**Relevant Section**: Section 2.4 (Main Libraries)

---

### 2.6 Multi-Tenant Data Isolation Relies on Application Logic Only

**Suggestion**: Section 3.3 mentions "Row-Level SecurityでテナントID自動フィルタ" (Automatic tenant_id filtering via Row-Level Security), which is good, but no details on RLS policy implementation or testing strategy.

**Rationale**:
- Multi-tenant SaaS has critical risk: Tenant A accessing Tenant B's data due to logic error
- RLS is powerful defense-in-depth but must be correctly configured for all tables
- Application-level tenant filtering bugs can bypass RLS if RLS policies are incomplete
- One tenant data leak can destroy entire business reputation

**Recommended Countermeasures**:
1. **Document PostgreSQL RLS policy implementation**:
   ```sql
   -- Example for employees table
   ALTER TABLE employees ENABLE ROW LEVEL SECURITY;

   -- Policy for application role
   CREATE POLICY tenant_isolation ON employees
       FOR ALL
       TO app_role
       USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

   -- Superuser can see all (for admin operations)
   CREATE POLICY tenant_admin ON employees
       FOR ALL
       TO admin_role
       USING (true);
   ```
   - Set `app.current_tenant_id` session variable on every database connection from tenant_id in JWT
   - Apply RLS policies to ALL tables with tenant_id column

2. **Add RLS testing to integration tests**:
   ```java
   @Test
   void testTenantIsolation() {
       // Create employees for two tenants
       Employee tenant1Employee = createEmployee(TENANT_1_ID);
       Employee tenant2Employee = createEmployee(TENANT_2_ID);

       // Authenticate as Tenant 1 user
       JWT tenant1Token = login(TENANT_1_USER);

       // Attempt to access Tenant 2 employee by ID
       assertThrows(AccessDeniedException.class, () -> {
           employeeService.getEmployee(tenant2Employee.getId(), tenant1Token);
       });

       // Verify can access own tenant employee
       assertDoesNotThrow(() -> {
           employeeService.getEmployee(tenant1Employee.getId(), tenant1Token);
       });
   }
   ```

3. **Add defense-in-depth with application-level checks**:
   - Even with RLS, add explicit tenant_id verification in service layer:
     ```java
     @PreAuthorize("hasRole('HR_MANAGER')")
     public Employee getEmployee(UUID employeeId, UUID requestingTenantId) {
         Employee employee = employeeRepository.findById(employeeId)
             .orElseThrow(() -> new NotFoundException("Employee not found"));

         // Defensive check (RLS should already filter, but verify)
         if (!employee.getTenantId().equals(requestingTenantId)) {
             auditLog.logSecurityViolation("TENANT_ISOLATION_VIOLATION", requestingTenantId, employeeId);
             throw new AccessDeniedException("Cross-tenant access denied");
         }
         return employee;
     }
     ```

4. **Automated RLS policy verification**:
   - Create database migration that verifies RLS is enabled on all tenant-scoped tables
   - Add Flyway afterMigrate callback to check for tables with tenant_id column but no RLS policy

**Relevant Section**: Section 3.3 (Data Flow), Section 4.1 (Data Model)

---

## 3. Confirmation Items (requiring user confirmation)

### 3.1 JWT Signing Algorithm Choice: HMAC-SHA256 vs RSA

**Confirmation Reason**: Section 6.1 specifies "トークンの署名アルゴリズム: HMAC-SHA256(共通鍵方式)" (JWT signing algorithm: HMAC-SHA256 with shared secret). This is simpler but has security trade-offs.

**Options and Trade-offs**:

**Option A: Keep HMAC-SHA256 (current design)**
- **Pros**:
  - Simpler implementation (single secret key)
  - Faster signature generation and verification
  - Sufficient for single-backend architecture
- **Cons**:
  - Any component that verifies JWT can also sign new tokens (no separation of concerns)
  - If secret is compromised, attacker can forge arbitrary tokens
  - Key rotation requires coordinated deployment (all instances must switch simultaneously)
  - Cannot delegate token verification to edge layer (ALB, CloudFront) without exposing signing capability

**Option B: Switch to RSA-256 (asymmetric)**
- **Pros**:
  - Private key for signing (stored in KMS), public key for verification (can be distributed)
  - ALB can verify JWT without access to signing key (better architecture)
  - Key rotation easier (publish new public key, old keys remain valid for verification during rotation period)
  - Better security posture for multi-service architecture
- **Cons**:
  - Slightly more complex implementation (key pair management)
  - Slower signature operations (not significant for typical login rates)
  - Larger token size (~200 bytes vs ~150 bytes)

**Recommendation**: If system may expand to microservices or API gateway-based verification in future, choose RSA-256 now to avoid migration later. If strictly single monolith, HMAC-SHA256 is acceptable but must use AWS Secrets Manager (not environment variables) for key storage.

**Question for user**: Do you plan to add additional services (mobile app backend, batch processing service, third-party integrations) that would need to verify JWTs independently in the next 12 months?

---

### 3.2 Disaster Recovery Targets: RTO 4 hours / RPO 24 hours

**Confirmation Reason**: Section 7.3 specifies "災害復旧目標(RTO): 4時間、RPO: 24時間" (RTO: 4 hours, RPO: 24 hours). For a payroll system, 24-hour data loss means potentially losing an entire day of:
- Attendance records (employees cannot reproduce exact clock-in/out times)
- Payroll calculation jobs
- Employee onboarding data
- Performance review submissions

**Options and Trade-offs**:

**Option A: Keep current targets (RTO 4h, RPO 24h)**
- **Pros**:
  - Lower cost (daily backups sufficient)
  - Simpler architecture
- **Cons**:
  - Up to 24 hours of data loss acceptable (confirm with business stakeholders)
  - May violate labor law requirements for accurate attendance records
  - Payroll re-calculation required if disaster occurs during month-end processing window

**Option B: Improve to RTO 1h, RPO 5 minutes**
- **Pros**:
  - Minimal data loss (RDS automated backups + transaction logs)
  - Better compliance posture
  - Faster recovery for business continuity
- **Cons**:
  - Requires RDS Multi-AZ deployment (higher cost ~2x)
  - Need cross-region read replica for regional disaster recovery
  - More complex failover procedures (document in runbook)
- **Implementation**:
  - Enable RDS Multi-AZ automatic failover (RTO ~1-2 minutes for AZ failure)
  - Enable RDS automated backups with PITR (Point-In-Time Recovery) to 5-minute granularity
  - For regional disaster: Cross-region read replica with manual promotion (RTO ~1 hour)

**Option C: Critical data only (improved RPO)**
- **Pros**:
  - Improve RPO for critical tables only (employees, payroll_records, attendance_records)
  - Use Change Data Capture (CDC) via AWS DMS to replicate critical tables to secondary region in near-real-time
  - Lower cost than full Multi-AZ
- **Cons**:
  - Partial replication complexity
  - Some data (evaluation, recruitment) still has 24h RPO

**Recommendation**: For payroll system handling employee financial data and legal compliance (attendance records), recommend Option B with RTO 1h / RPO 5 minutes via RDS Multi-AZ + automated backups.

**Question for user**: What is acceptable data loss window from business perspective? Consider:
- Can employees re-enter lost attendance records from memory?
- What happens if disaster occurs on payroll calculation day (monthly)?
- Are there contractual SLAs with customers (enterprise clients)?

---

### 3.3 Compliance Scope: GDPR Applicability

**Confirmation Reason**: Design mentions APPI (Japan privacy law) and My Number Act but doesn't clarify if system will process EU residents' data, which triggers GDPR requirements.

**Options and Trade-offs**:

**Option A: Japan-only operations (no GDPR)**
- **Pros**:
  - No need for GDPR-specific controls (data portability, right to erasure automation)
  - Simpler privacy policy and consent management
- **Cons**:
  - Limits market expansion to EU/EEA customers
  - If even one EU employee is in system, GDPR applies

**Option B: GDPR compliance required**
- **Additional requirements**:
  1. **Data Subject Access Request (DSAR) automation**: Add `/api/gdpr/export-my-data` endpoint to export all personal data in machine-readable format (JSON)
  2. **Right to erasure**: Implement anonymization workflow (cannot delete due to 7-year payroll retention requirement under Japanese tax law, so must anonymize instead)
  3. **Consent management**: Add consent tracking for optional data processing (e.g., performance evaluation data retention beyond legal minimum)
  4. **Data Processing Agreement (DPA)**: Execute DPA with Datadog, AWS as data processors
  5. **Data Protection Impact Assessment (DPIA)**: Required for high-risk processing (My Number + salary data)
  6. **EU representative appointment**: If serving EU customers but no EU establishment
- **Pros**:
  - Enables EU market expansion
  - Stronger privacy posture benefits all users
- **Cons**:
  - Development effort for DSAR/erasure automation (~2-3 weeks)
  - Legal compliance overhead (DPA, DPIA, representative)

**Question for user**: Will this system process data of:
1. Employees working in EU/EEA countries (even for Japanese companies)?
2. EU citizens working in Japan?
3. Plans to sell service to EU-based companies?

If answer is "yes" to any, recommend implementing GDPR controls in initial design (cheaper than retrofit).

---

## 4. Positive Evaluation (good points)

### 4.1 Multi-Tenant Architecture with Row-Level Security

The design appropriately adopts PostgreSQL Row-Level Security (RLS) as defense-in-depth for tenant data isolation (Section 3.3). RLS provides database-level enforcement independent of application logic, protecting against:
- Application bugs that forget to filter by tenant_id
- SQL injection that bypasses ORM query construction
- Direct database access scenarios (e.g., batch jobs, data migration scripts)

This is a best practice for SaaS applications and demonstrates security-conscious design. Recommendation to further strengthen: Document RLS policy implementation details and add automated testing (see Section 2.6).

---

### 4.2 HTTPS-Only Communication

Section 7.2 specifies "通信は全てHTTPSで暗号化" (All communication encrypted via HTTPS), which properly protects:
- JWT tokens in transit (preventing session hijacking on network)
- Personal data in API requests/responses
- Credentials during login flow

Ensure this is enforced at infrastructure level (ALB listener redirects HTTP→HTTPS, HSTS header enabled) rather than relying on application code.

---

### 4.3 Password Hashing with bcrypt

Section 7.2 correctly specifies bcrypt with work factor 10 for password storage. bcrypt is appropriate for password hashing due to:
- Adaptive cost factor (can increase over time as hardware improves)
- Built-in salt generation
- Resistance to GPU-based attacks (unlike SHA-256)

Work factor 10 is reasonable for 2024 (targets ~100ms hashing time). Consider increasing to 12 in next 2-3 years as hardware improves.

---

### 4.4 UUID Primary Keys for Entities

Section 4.1 uses UUID primary keys for all major entities (employees, attendance_records, payroll_records). This provides:
- No enumeration attacks (cannot guess valid IDs)
- Safe to expose in API URLs without leaking record count or creation order
- Cross-database migration without ID conflicts
- Better multi-tenant isolation (harder to accidentally reference wrong tenant's records)

This is a security and scalability best practice.

---

### 4.5 Spring Security Integration with Role-Based Access Control

Section 6.1 uses Spring Security's `@PreAuthorize` annotation for declarative authorization. This provides:
- Centralized permission logic (not scattered across service methods)
- Compile-time validation of permission expressions (via SpEL)
- Framework-level enforcement (cannot be bypassed by forgetting checks)
- Clear authorization requirements visible in code

Example from Section 5.2: `GET /api/employees` requires `HR_MANAGER` or `ADMIN` role. This is properly enforced at controller level.

---

## Summary

This HR & Payroll system design has **critical security issues requiring immediate remediation** before implementation:

**Must Fix (Score 1-2 issues)**:
1. **Data Protection**: Encrypt My Number, bank accounts, and salaries at rest (regulatory violation, Critical Issue 1.1)
2. **Secrets Management**: Move JWT signing key and DB password to AWS Secrets Manager (Critical Issue 1.2)
3. **Logging**: Redact personal data from operational logs (GDPR/APPI violation, Critical Issue 1.3)
4. **Session Management**: Implement refresh tokens + session revocation (Critical Issue 1.4)
5. **Rate Limiting**: Add brute-force protection and API rate limiting (Critical Issue 1.5)

**Recommended Improvements**:
- Document input validation strategy (Section 2.1)
- Enhance audit logging with detailed event catalog (Section 2.2)
- Clarify JWT storage location and CSRF protection (Section 2.3)
- Secure database backups with encryption and access controls (Section 2.4)
- Implement dependency vulnerability scanning (Section 2.5)
- Add multi-tenant isolation testing (Section 2.6)

**Design Strengths**:
- RLS for tenant isolation
- HTTPS enforcement
- bcrypt password hashing
- UUID primary keys
- Spring Security RBAC integration

**Overall Assessment**: The architecture foundation is solid (Spring Boot, PostgreSQL, multi-tenant design), but security implementation details are critically insufficient for a system handling sensitive HR and financial data. Addressing the 5 critical issues is mandatory before proceeding to implementation phase. Estimated remediation effort: 3-4 weeks for development + security review.
