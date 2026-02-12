### Generality Critique Results

#### Critical Issues (Domain over-dependency)
None - All items are conditionally generic with appropriate scope

#### Scope Item Generality
| Item | Classification | Failed Dimensions | Proposal |
|------|----------------|------------------|----------|
| 1. 多要素認証(MFA)の実装 | Conditional | None (Prerequisite: User authentication systems) | Add prerequisite note: "ユーザー認証機能を持つシステムに適用" |
| 2. OAuth 2.0 / OIDC 対応 | Conditional | None (Technology standard: IETF RFC 6749, OpenID Connect) | Retain as conditional generic - OAuth 2.0/OIDC are widely adopted industry standards, not vendor-specific. Prerequisite: "外部IdP連携を行うシステムに適用" |
| 3. セッション管理の安全性 | Conditional | None (Prerequisite: Stateful authentication systems) | Add prerequisite note: "セッションベース認証を採用するシステムに適用" |
| 4. パスワードポリシー | Conditional | None (Prerequisite: Password-based authentication) | Add prerequisite note: "パスワード認証を採用するシステムに適用" |
| 5. 権限の粒度設計 | Conditional | None (Prerequisite: Multi-user systems with access control) | Add prerequisite note: "複数ユーザー・権限レベルを持つシステムに適用" |

**Context Portability Analysis**:
- **B2C apps**: Meaningful (2/2) - Web/mobile apps with user login
- **Internal tools**: Meaningful (2/2) - Enterprise systems with employee authentication
- **OSS libraries**: Not meaningful (0/2) - Auth libraries are infrastructure, not target of this perspective

**Classification Rationale**: All 5 items pass 2/3 context tests and 2/3 evaluation dimensions (industry applicability + regulation neutrality, but conditional on technology stack prerequisite: "user authentication system").

#### Problem Bank Generality
- Generic: 0
- Conditional: 4
- Domain-Specific: 0

**Problem Bank Analysis**:
All problem entries are conditionally generic - applicable to any system with authentication:
- "MFAが未実装" - Relevant to finance, healthcare, SaaS, e-commerce (any B2C/B2B auth system)
- "セッションタイムアウトが無制限" - Universal session management concern (ISO 27001)
- "パスワードが平文で保存されている" - Critical security anti-pattern across all industries (OWASP Top 10)
- "全ユーザーに管理者権限が付与されている" - Violates principle of least privilege (NIST framework)

No industry-specific terminology or jargon detected.

#### Improvement Proposals
- **Proposal 1**: **Add explicit prerequisite statement** to perspective introduction: "本観点はユーザー認証・認可機能を持つシステムを対象としています。以下のシステムには適用されません: 組込みファームウェア、バッチ処理パイプライン、ステートレスな計算ライブラリ等"

- **Proposal 2**: Clarify OAuth 2.0 / OIDC as **technology standard** (not vendor-specific) - These are IETF/OpenID Foundation standards adopted across Google, Microsoft, GitHub, Okta, Auth0, etc. Similar to REST or GraphQL in API design.

- **Proposal 3**: Add sub-prerequisites for individual items:
  - Item 3: "Stateful authentication (session/cookie-based)" vs stateless (JWT/token-based)
  - Item 4: "Password-based authentication" (not applicable to passwordless/biometric-only systems)

#### Positive Aspects
- **Strong technology standard alignment**: OAuth 2.0/OIDC reference is appropriate - these are IETF standards (RFC 6749, RFC 7519), not vendor-specific protocols. Similar to referencing REST or GraphQL in API design perspectives.
- **Industry-independence within domain**: All 5 items apply equally to:
  - Finance (banking apps with MFA)
  - Healthcare (patient portal security)
  - E-commerce (customer account security)
  - SaaS (enterprise tenant authentication)
- **Regulation-neutral**: No specific compliance references (no PCI-DSS, HIPAA, SOX) - items extract underlying security principles
- **Terminology is jargon-free**: Uses industry-standard terms (MFA, OAuth, RBAC, ABAC) that are universally understood across industries
- **Problem bank is contextually appropriate**: All entries are meaningful to authentication-enabled systems without industry bias
- **Signal-to-noise ratio: 5/5 conditionally generic items** - ideal for a conditional perspective
- **Well-scoped prerequisite boundary**: Clear distinction between "systems with authentication" (in scope) vs "infrastructure libraries" or "embedded systems" (out of scope)

**Overall Assessment**: This perspective is an exemplar of **conditional generality** - it correctly identifies a meaningful prerequisite ("user authentication systems") and applies universal security principles within that boundary. No redesign needed; only prerequisite clarification recommended.
