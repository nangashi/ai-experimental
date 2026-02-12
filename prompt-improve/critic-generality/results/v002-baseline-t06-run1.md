### Generality Critique Results

#### Critical Issues (Domain over-dependency)
None

#### Scope Item Generality
| Item | Classification | Failed Dimensions | Proposal |
|------|----------------|------------------|----------|
| 1. 多要素認証(MFA)の実装 | Conditionally Generic | None (passes all 3 dimensions under user authentication context) | Add prerequisite note: "Applies to systems with user authentication features" |
| 2. OAuth 2.0 / OIDC 対応 | Conditionally Generic | None (OAuth 2.0/OIDC are widely adopted technology standards, not niche tech) | Add prerequisite note: "Applies to systems with external identity provider integration needs" |
| 3. セッション管理の安全性 | Conditionally Generic | None | Add prerequisite note: "Applies to systems with session-based authentication" |
| 4. パスワードポリシー | Conditionally Generic | None | Add prerequisite note: "Applies to systems using password-based authentication" |
| 5. 権限の粒度設計 | Conditionally Generic | None | Add prerequisite note: "Applies to systems with user authorization requirements" |

**Prerequisite Condition**: All 5 items assume "systems with user authentication/authorization features". This is a **conditionally generic** perspective that does not apply to:
- Embedded firmware without user login
- Batch processing pipelines without user interaction
- Data transformation libraries/utilities
- Single-user desktop applications without authentication
- Hardware control systems

#### Problem Bank Generality
- Generic (within authentication context): 4
- Conditional: 0
- Domain-Specific: 0

**Problem Bank Assessment**: All problem examples are appropriate for systems with authentication features:
- "MFAが未実装" - applies to any multi-user system requiring secure authentication (B2C apps, internal tools, SaaS platforms)
- "セッションタイムアウトが無制限" - universal session management concern
- "パスワードが平文で保存されている" - fundamental security issue across industries
- "全ユーザーに管理者権限が付与されている" - authorization design flaw applicable to any role-based system

**Technology Standard Evaluation**: OAuth 2.0 / OIDC (item 2) are widely adopted open standards supported by major identity providers (Google, Microsoft, GitHub, Okta, Auth0). While technically specific protocols, they represent common technology patterns (REST-based) rather than niche/proprietary tech, passing the "Conditional: Common stacks" criterion.

#### Improvement Proposals
- **Add Prerequisite Section**: Insert at the beginning of the perspective definition: "この観点は、ユーザー認証・認可機能を持つシステムを対象とします。組込みシステム、バッチ処理パイプライン、ユーザーログインのない単一ユーザーアプリケーションには適用されません。"
- **Alternative Approach**: Rename perspective to "ユーザー認証・認可観点" to make the scope explicit in the title
- **No Item Deletion Needed**: All 5 items are appropriately scoped once the prerequisite is clarified

#### Positive Aspects
- All scope items represent industry best practices for authentication/authorization (finance, healthcare, e-commerce, SaaS all need secure authentication)
- No dependency on specific regulations (not tied to PCI-DSS, HIPAA, SOX, GDPR)
- OAuth 2.0 / OIDC represents a pragmatic balance - widely adopted standards applicable across industries without being overly abstract
- Problem bank examples are technology-neutral (no "check AWS Cognito settings" or "verify Auth0 configuration")
- Concepts (MFA, session management, password policy, RBAC/ABAC) are well-established security principles documented in OWASP, NIST, and ISO standards
