### Generality Critique Results

#### Critical Issues (Domain over-dependency)
None - but requires explicit applicability scoping

#### Scope Item Generality
| Item | Classification | Failed Dimensions | Proposal |
|------|----------------|------------------|----------|
| 1. 多要素認証(MFA)の実装 | Conditional Generic | Industry Applicability (requires user authentication systems) | No change to content, but add perspective-level note: "ユーザー認証機能を持つシステムに適用" (Applies to systems with user authentication). Passes across industries with authentication (finance, healthcare, SaaS) |
| 2. OAuth 2.0 / OIDC 対応 | Conditional Generic | Regulation Dependency (common standard, but not universal) | Acceptable as-is - OAuth/OIDC are widely adopted open standards (not vendor-specific). Consider adding "または同等の認証プロトコル" (or equivalent authentication protocol) for future-proofing |
| 3. セッション管理の安全性 | Conditional Generic | Industry Applicability (requires session-based systems) | No change needed - session management applies to web apps, mobile backends, and interactive systems broadly |
| 4. パスワードポリシー | Conditional Generic | Industry Applicability (requires password-based authentication) | No change needed - password policies apply wherever password authentication exists (though some systems use passwordless) |
| 5. 権限の粒度設計 | Conditional Generic | Industry Applicability (requires multi-user systems) | No change needed - RBAC/ABAC concepts apply across industries to any system with access control requirements |

#### Problem Bank Generality
- Generic: 4 (all entries, conditional on authentication context)
- Conditional: 0
- Domain-Specific: 0

**Problem Bank Analysis**: All 4 problem examples are broadly applicable to authentication systems:
1. "MFAが未実装" - Relevant to web apps, mobile apps, enterprise systems
2. "セッションタイムアウトが無制限" - Universal session management issue
3. "パスワードが平文で保存されている" - Critical security flaw across all contexts
4. "全ユーザーに管理者権限が付与されている" - Authorization anti-pattern applicable everywhere

**Context Portability Test**: All items are meaningful in:
- B2C app (user login, social auth, session management) ✓
- Internal tool (employee authentication, SSO, role management) ✓
- OSS library (authentication SDK, authorization framework) ✓

However, items are NOT applicable to:
- Embedded systems without user accounts (IoT sensors, firmware)
- Batch processing pipelines without interactive access
- Purely public APIs without authentication requirements

#### Improvement Proposals
- **Add Applicability Scope Statement**: Recommend adding to perspective introduction: "**適用対象**: このperspectiveはユーザー認証・認可機能を持つシステムに適用されます。認証機能を持たないシステム（組込みファームウェア、バッチ処理パイプライン等）には適用されません。" (Applicability: This perspective applies to systems with user authentication/authorization. Not applicable to systems without authentication such as embedded firmware, batch processing pipelines.)
- **Clarify OAuth/OIDC as Example**: While OAuth 2.0/OIDC are widely adopted standards (not vendor-specific), consider rephrasing Item 2 to "外部IdPとの連携設計（OAuth 2.0 / OIDC等）" to indicate these are examples of federation protocols, not exclusive requirements.

**Overall Assessment**: No item-level redesign needed. This is a well-scoped conditional generic perspective. The key improvement is making the precondition (user authentication systems) explicit in the perspective header.

#### Positive Aspects
- **Industry-Neutral Within Scope**: MFA, session management, RBAC/ABAC apply equally to finance, healthcare, e-commerce, SaaS, government, and education systems
- **Technology Standard, Not Vendor-Specific**: OAuth 2.0/OIDC are open standards (RFC 6749, OIDC Core), not proprietary solutions - appropriate for a generic perspective
- **Security Best Practices**: All items reflect established security principles (defense in depth, least privilege, secure session handling) recognized across OWASP, NIST, and ISO standards
- **Appropriate Granularity**: Specifies security mechanisms (MFA, session timeout, password policy) at the right abstraction level - concrete enough to evaluate, generic enough to apply across implementations
- **No Regulatory Lock-In**: While MFA may be required by regulations (PCI-DSS, HIPAA), the perspective doesn't assume any specific regulation - it presents MFA as a general security practice
