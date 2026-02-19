### Generality Critique Results

#### Critical Issues (Domain over-dependency)
None

#### Scope Item Generality
| Item | Classification | Failed Dimensions | Proposal |
|------|----------------|------------------|----------|
| 1. 多要素認証(MFA)の実装 | Conditionally Generic | None (passes all 3, but conditional on user authentication) | Mark as conditional: "ユーザー認証機能を持つシステムにおけるMFA実装" - applies to web apps, SaaS, enterprise tools, but not to batch jobs, embedded systems, or data pipelines |
| 2. OAuth 2.0 / OIDC 対応 | Conditionally Generic | None (passes all 3, but conditional on external identity provider integration) | Acceptable as-is - OAuth 2.0 / OIDC are widely adopted open standards (not vendor-specific). Applies to systems requiring federated identity, but note prerequisite: "外部IdP連携が必要なシステムにおける対応" |
| 3. セッション管理の安全性 | Conditionally Generic | None (conditional on session-based authentication) | Mark as conditional: applies to stateful web applications, but not to stateless JWT-only APIs or certificate-based authentication systems |
| 4. パスワードポリシー | Conditionally Generic | None (conditional on password authentication) | Mark as conditional: applies where password authentication exists, increasingly less relevant with passwordless/passkey adoption |
| 5. 権限の粒度設計 | Conditionally Generic | None (conditional on multi-user systems) | Acceptable as generic within authentication domain - RBAC/ABAC concepts apply to any system with access control needs |

#### Problem Bank Generality
- Generic: 4 (within the authentication domain)
- Conditional: 0
- Domain-Specific: 0

Problem bank observation: All examples are appropriate for systems with user authentication:
- "MFAが未実装" - generic concern for authenticated systems
- "セッションタイムアウトが無制限" - applies to session-based auth
- "パスワードが平文で保存されている" - critical security issue, universally applicable where passwords exist
- "全ユーザーに管理者権限が付与されている" - RBAC misconfiguration, generic concern

#### Improvement Proposals
- **Add explicit prerequisite statement**: Insert at perspective introduction: "本観点は、ユーザー認証機能を持つシステム(Webアプリケーション、モバイルアプリ、企業向けSaaS等)を対象とする。認証機能を持たないシステム(組込みファームウェア、バッチ処理、データパイプライン等)には適用対象外である"
- **Item 2 clarification**: OAuth 2.0 / OIDC are technology **standards** (not specific vendor products), making them more generic than proprietary solutions. Keep as-is, but consider adding note: "外部IdP連携が不要な場合は対象外"
- **Item 3 refinement**: Add note that stateless authentication (JWT, API keys) has different security considerations than session-based auth
- **Item 4 future consideration**: As passwordless authentication (WebAuthn, passkeys) becomes prevalent, consider renaming to "認証要素の強度設計" to cover both password and passwordless scenarios

#### Positive Aspects
- All 5 items are **industry-independent** - authentication concerns apply equally to finance, healthcare, e-commerce, education, government systems
- **No regulation-specific dependencies** - no HIPAA, PCI-DSS, SOX references. The requirements are security best practices, not compliance-driven
- **Technology stack agnostic** - OAuth 2.0 / OIDC are open standards, not tied to specific vendors (Auth0, Okta, AWS Cognito are implementations, not mentioned here)
- Problem bank uses universal authentication anti-patterns without domain jargon
- Cross-context applicability (among authenticated systems):
  - B2C app: ✓ (MFA, OAuth, session security all relevant)
  - Internal tool: ✓ (RBAC critical for enterprise IAM)
  - OSS library: Partial (if the library provides authentication, these apply; if it's authentication-agnostic, N/A)
- This perspective demonstrates **good conditional generality** - it clearly targets a specific functional domain (authentication) but within that domain, applies broadly across industries and technology stacks
- **Recommendation**: This is acceptable as a **conditionally generic perspective** if prerequisite is explicitly stated. No redesign needed, only documentation improvement.
