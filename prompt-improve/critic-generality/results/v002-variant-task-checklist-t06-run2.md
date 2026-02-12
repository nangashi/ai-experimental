### Generality Critique Results

#### Critical Issues (Domain over-dependency)
None

#### Scope Item Generality
| Item | Classification | Failed Dimensions | Proposal |
|------|----------------|------------------|----------|
| 1. 多要素認証(MFA)の実装 | Conditionally Generic | None (passes all dimensions under prerequisite) | Add prerequisite: "ユーザー認証機能を持つシステムに適用". Generic within authentication context |
| 2. OAuth 2.0 / OIDC 対応 | Conditionally Generic | None (widely adopted standard) | Keep as-is. OAuth 2.0/OIDC are industry standards (not niche tech). Add note: "外部IdP連携が必要なシステム向け" |
| 3. セッション管理の安全性 | Conditionally Generic | None | Add prerequisite: "ステートフルなセッションを持つシステムに適用". Stateless systems (pure API tokens) may not need session management |
| 4. パスワードポリシー | Conditionally Generic | None | Add prerequisite: "パスワード認証を採用するシステムに適用". Passwordless systems excluded |
| 5. 権限の粒度設計 | Conditionally Generic | None | Add prerequisite: "複数ユーザー/ロールを持つシステムに適用". Single-user or public systems excluded |

#### Problem Bank Generality
- Generic: 4 (within authentication context)
- Conditional: 0
- Domain-Specific: 0

**Detailed Analysis:**
- All problem examples are meaningful for systems with authentication (B2C app with user login, internal tool with employee access, OSS library with admin interface)
- Not applicable to: Embedded firmware without user concept, batch processing systems, public APIs without authentication
- Terminology is industry-neutral (no finance/healthcare/e-commerce jargon)

**Conditional Generality Justification:**
- Industry Applicability: 7+/10 projects have authentication → passes threshold
- Regulation Dependency: References OAuth/OIDC standards but not industry-specific regulations (not PCI-DSS/HIPAA) → passes
- Technology Stack: RBAC/ABAC are concepts, not specific products → passes
- Classification: Conditionally Generic (requires "systems with user authentication" prerequisite)

#### Improvement Proposals
- Add prerequisite section at perspective definition start: "**適用対象**: ユーザー認証・認可機能を持つシステム（Webアプリ、モバイルアプリ、API、内部ツール等）。認証機能を持たないシステム（組込みファームウェア、データ処理パイプライン、パブリックAPI等）には適用外。"
- Consider renaming item 2 to "外部IdP連携（OAuth 2.0 / OIDC等）の設計" to make standard examples rather than requirements
- No changes needed for problem bank - examples are appropriately scoped

#### Positive Aspects
- All items represent widely applicable authentication/authorization best practices
- OAuth 2.0 / OIDC are global standards adopted across industries (not proprietary protocols)
- Concepts (MFA, session security, password policies, RBAC/ABAC) apply equally to finance, healthcare, e-commerce, SaaS, government systems
- Problem examples are concrete yet domain-neutral
- Clear prerequisite (authentication functionality) makes conditional generality explicit and acceptable
