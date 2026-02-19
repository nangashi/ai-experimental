### Generality Critique Results

#### Critical Issues (Domain over-dependency)
None

**Context Applicability**: This perspective applies to systems with user authentication. It does NOT apply to:
- Embedded firmware without user accounts
- Batch processing jobs without interactive users
- Internal libraries/SDKs without authentication layers
- IoT devices with device-based (not user-based) authentication

#### Scope Item Generality
| Item | Classification | Failed Dimensions | Proposal |
|------|----------------|------------------|----------|
| 1. 多要素認証(MFA)の実装 | Conditional Generic | None (prerequisite: user authentication system) | Keep as-is, but note prerequisite. Applies to any user-facing system where security is important (B2C apps, enterprise tools, admin panels) |
| 2. OAuth 2.0 / OIDC 対応 | Conditional Generic | None (prerequisite: external identity integration) | Keep as-is. OAuth 2.0 and OIDC are widely adopted open standards, not vendor-specific. Conditional on needing external IdP integration |
| 3. セッション管理の安全性 | Conditional Generic | None (prerequisite: session-based authentication) | Keep as-is. Applies to any system using sessions (web apps, mobile apps with token-based auth) |
| 4. パスワードポリシー | Conditional Generic | None (prerequisite: password-based authentication) | Keep as-is. Applies to systems using password authentication (still the majority of user-facing systems) |
| 5. 権限の粒度設計 | Conditional Generic | None (prerequisite: multi-user system with access control) | Keep as-is. RBAC/ABAC concepts apply across industries and tech stacks for any multi-user system |

#### Problem Bank Generality
- Generic: 0 (all are conditional generic)
- Conditional: 4 (all examples apply to authentication-enabled systems)
- Domain-Specific: 0

**Problem Bank Assessment**:
- "MFAが未実装" - Applies to any authentication system where MFA should be considered
- "セッションタイムアウトが無制限" - Session management issue applicable across web/mobile apps
- "パスワードが平文で保存されている" - Universal security anti-pattern for password-based systems
- "全ユーザーに管理者権限が付与されている" - Access control issue applicable to any multi-user system

#### Improvement Proposals
- **Add prerequisite statement**: Recommend adding a clear prerequisite section to the perspective definition:
  ```
  ## 適用前提
  本観点は、ユーザー認証機能を持つシステムに適用されます。
  適用例: Webアプリケーション、モバイルアプリ、管理ツール、SaaS製品
  非適用例: 組込みファームウェア、バッチ処理システム、認証レイヤーを持たないライブラリ
  ```
  (Prerequisite: This perspective applies to systems with user authentication functionality.
  Applicable: Web apps, mobile apps, admin tools, SaaS products
  Not applicable: Embedded firmware, batch processing, libraries without auth layers)

- **OAuth 2.0 / OIDC clarification**: The perspective correctly identifies OAuth 2.0 and OIDC as industry standards (not vendor lock-in). These are protocol specifications adopted by Google, Microsoft, GitHub, and many others. This is an example of **appropriate use of standards** in a generic perspective.

#### Positive Aspects
- **All 5 items are conditionally generic with a clear, consistent prerequisite**: They apply broadly to any system with user authentication
- **No vendor lock-in**: OAuth 2.0 / OIDC are open standards, not proprietary technologies. The perspective allows for any IdP (Google, Microsoft, GitHub, self-hosted solutions)
- **No industry-specific requirements**: These authentication/authorization concepts apply equally to finance, healthcare, e-commerce, SaaS, and other industries
- **No regulation-specific requirements**: While regulations like PCI-DSS or HIPAA may require these controls, the perspective doesn't assume any specific regulation
- **Technology stack agnostic**: MFA, session management, password policies, and RBAC/ABAC can be implemented in any language, framework, or architecture
- **Clear conditional boundary**: The prerequisite (user authentication system) is well-defined and easy to evaluate
- **Appropriate abstraction level**: Focuses on security principles (MFA, session safety, password policy) rather than specific implementations
- **Well-suited for "conditional generic" template**: This perspective is an excellent example of how to design perspectives with clear applicability conditions
