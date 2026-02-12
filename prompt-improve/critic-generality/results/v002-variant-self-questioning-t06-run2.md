# T06 Evaluation Result

## Self-Questioning Process

### Understanding Phase
- **Core purpose**: Ensure authentication and authorization are properly designed
- **Assumptions**: System has user authentication functionality

### Classification Phase

#### Item 1: 多要素認証(MFA)の実装
- **Does this apply across industries?**: Yes - finance, healthcare, SaaS, e-commerce all use MFA
- **3 counter-examples where MFA exists**: Banking apps, medical portals, enterprise SaaS
- **Does this assume specific regulations?**: No - MFA is best practice, not regulation-specific
- **Does this assume specific tech?**: No - mentions multiple options (SMS, TOTP, biometric)
- **But does it apply to ALL systems?**: No - embedded systems, batch jobs, IoT devices may not have user authentication
- **Classification**: Conditionally Generic (requires "user authentication" as precondition)

#### Item 2: OAuth 2.0 / OIDC 対応
- **3 counter-examples**: SaaS platforms, mobile apps, web applications
- **Is OAuth/OIDC industry jargon?**: No - widely adopted technical standard
- **Is this niche tech?**: No - OAuth 2.0 is common stack (RFC 6749), OIDC is industry standard
- **Self-check**: "Am I confusing 'common practice' with 'generic applicability'?"
  - OAuth/OIDC are open standards, not proprietary technologies
  - Supported by major IdPs (Google, Microsoft, GitHub, Okta, Auth0)
  - Classification: Conditionally Generic (standard protocol, but requires external IdP integration use case)

#### Item 3: セッション管理の安全性
- **3 industries**: Finance (online banking), Healthcare (patient portals), E-commerce (shopping sites)
- **Does "session" apply everywhere?**: Yes - web apps, mobile apps, desktop apps with login
- **Classification**: Conditionally Generic (requires user sessions)

#### Item 4: パスワードポリシー
- **3 industries**: All systems with password authentication
- **Classification**: Conditionally Generic (requires password-based authentication)

#### Item 5: 権限の粒度設計
- **3 industries**: Enterprise systems, SaaS platforms, healthcare systems
- **RBAC/ABAC are industry jargon?**: No - common access control models
- **Classification**: Conditionally Generic (requires multi-user systems with access control)

### Synthesis Phase

**Key question**: "If multiple dimensions show different classifications, which is the limiting factor?"

- **All items pass Industry and Regulation dimensions** (apply across finance, healthcare, e-commerce, SaaS)
- **All items pass Technology Stack dimension** (not tied to specific frameworks)
- **All items fail on a hidden dimension**: System type - not all systems have user authentication

**Limiting factor**: Precondition of "user authentication functionality"

**Evidence for conditional classification**:
- Systems WITHOUT user authentication: Embedded firmware, data pipelines, internal libraries, batch processing scripts, IoT sensors
- Systems WITH user authentication: Web applications, mobile apps, enterprise systems, SaaS platforms (majority of projects, approximately 6-7/10)

**Self-check**: "Have I tested against at least 3 different industry contexts?"
- Yes: Finance (banking), Healthcare (portals), E-commerce (shopping), SaaS (enterprise tools)

**Self-check**: "What evidence supports my final classification?"
- All items are universally relevant to "systems with user authentication"
- None apply to "systems without user authentication"
- This represents a legitimate precondition, not a domain limitation

---

## Evaluation Results

### Critical Issues (Domain over-dependency)

None

### Scope Item Generality

| Item | Classification | Failed Dimensions | Proposal |
|------|----------------|------------------|----------|
| 1. 多要素認証(MFA)の実装 | Conditionally Generic | Precondition: User authentication | Add precondition statement to perspective introduction |
| 2. OAuth 2.0 / OIDC 対応 | Conditionally Generic | Precondition: User authentication + External IdP | Keep as-is; OAuth/OIDC are industry standards, not niche tech |
| 3. セッション管理の安全性 | Conditionally Generic | Precondition: User authentication | Add precondition statement to perspective introduction |
| 4. パスワードポリシー | Conditionally Generic | Precondition: Password-based auth | Add precondition statement to perspective introduction |
| 5. 権限の粒度設計 | Conditionally Generic | Precondition: Multi-user access control | Add precondition statement to perspective introduction |

**All items are Conditionally Generic with the same precondition: "システムがユーザー認証機能を持つ"**

### OAuth 2.0 / OIDC Technology Standard Evaluation

**Self-questioning**: "Is OAuth/OIDC a 'specific technology' or a 'common standard'?"

- **RFC Status**: OAuth 2.0 (RFC 6749) and OIDC (OpenID Connect Core 1.0) are open standards
- **Adoption**: Supported by Google, Microsoft, GitHub, Facebook, Apple, Okta, Auth0, Keycloak, etc.
- **Comparison**: Similar to HTTP, REST, SQL - widely adopted protocols/standards
- **Conclusion**: Common standard, not niche technology → Passes Technology Stack dimension

**This is analogous to including "REST API design" in an API perspective - it's a standard, not a vendor lock-in.**

### Problem Bank Generality

- Generic: 0
- Conditional: 4
- Domain-Specific: 0

**Conditionally Generic entries** (all 4 problems):
- "MFAが未実装" - Applies to authentication-enabled systems
- "セッションタイムアウトが無制限" - Applies to session-based systems
- "パスワードが平文で保存されている" - Applies to password-based systems
- "全ユーザーに管理者権限が付与されている" - Applies to multi-user systems

**All problems are appropriate for systems with user authentication.**

### Precondition Specification

**Systems where this perspective applies**:
- Web applications with user login
- Mobile applications with user accounts
- Enterprise systems with employee authentication
- SaaS platforms with customer access
- API services with authenticated endpoints

**Systems where this perspective does NOT apply**:
- Embedded firmware (no user authentication)
- Data processing pipelines (system-to-system only)
- Internal libraries and SDKs
- Batch processing scripts
- IoT sensors (device authentication, not user authentication)
- Static websites (no authentication)

**Estimated applicability**: ~60-70% of software projects

### Improvement Proposals

1. **Add Precondition Statement to Perspective Introduction**
   - **Proposed addition**:
     ```
     ## 適用対象
     本観点は、以下の特性を持つシステムに適用されます：
     - ユーザー認証機能を持つ（ログイン/ログアウト）
     - 複数ユーザーまたはロールによるアクセス制御がある

     適用対象外: 組込みファームウェア、データ処理パイプライン、認証機能のない内部ツール等
     ```
   - **Reason**: Makes preconditions explicit, preventing misapplication to inappropriate systems
   - **Best practice**: "Conditional generality requires explicit precondition documentation"

2. **Item 2 - Keep OAuth/OIDC as-is**
   - **Reason**: OAuth 2.0 / OIDC are industry-standard protocols, analogous to including "HTTPS" or "JWT" in security reviews
   - **Not domain-specific**: Open standards with broad adoption across industries and vendors
   - **Evidence**: Would we remove "SQL" from a data model perspective? No, because it's a common standard

3. **No Changes to Problem Bank**
   - **Reason**: All problem examples are appropriate for authentication-enabled systems
   - **Quality**: Problems avoid vendor-specific jargon and focus on design flaws

### Positive Aspects

- **Technology-agnostic**: Avoids vendor lock-in (no "use Auth0" or "use Okta" mandates)
- **Industry-independent**: MFA, session management, and RBAC apply across finance, healthcare, e-commerce, SaaS
- **Standard-based**: References OAuth 2.0 / OIDC (open standards, not proprietary protocols)
- **Comprehensive coverage**: Addresses authentication (Items 1-4) and authorization (Item 5)
- **Multiple implementation options**: Item 1 explicitly mentions SMS, TOTP, biometric - showing technology flexibility
- **Practical focus**: Each item addresses real security concerns in authentication design
- **Clear precondition**: "User authentication" is a legitimate, well-defined precondition that applies to majority of projects

**This perspective exemplifies proper "conditional generality" - it clearly applies to a well-defined subset of systems (authentication-enabled) rather than being overly specialized (e.g., "healthcare-only") or artificially universal.**
