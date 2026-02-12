### Generality Critique Results

#### Critical Issues (Perspective overly dependent on specific domains)
None

#### Scope Item Generality Evaluation
| Scope Item | Classification | Reason | Improvement Proposal |
|------------|----------------|--------|---------------------|
| 多要素認証(MFA)の実装 | Conditionally Generic | MFA applies to systems with user authentication. Not applicable to embedded systems without user login, batch processing tools, or internal libraries. Tested on user-facing SaaS (relevant), data processing pipeline (no users - irrelevant), IoT firmware (no authentication - irrelevant). Passes for 7/10 projects that have user accounts. | Add prerequisite: "ユーザー認証機能を持つシステム向け" at perspective introduction. The concept itself is widely applicable across web apps, mobile apps, enterprise systems. |
| OAuth 2.0 / OIDC 対応 | Conditionally Generic | OAuth 2.0 and OpenID Connect are widely adopted industry standards, applicable to most systems requiring third-party authentication. Not industry-specific but assumes authentication requirements. Relevant to SaaS, mobile apps, enterprise portals; less relevant to closed internal tools or embedded systems. | Prerequisite note sufficient: "外部IdP連携を行うシステム向け". OAuth/OIDC are standardized protocols, not vendor-specific tools, making them appropriately generic for systems needing federated authentication. |
| セッション管理の安全性 | Conditionally Generic | Session management (timeouts, token rotation, secure cookies) applies broadly to web applications, mobile backends, and APIs with stateful authentication. Not applicable to stateless services, batch jobs, or systems without user sessions. | Acceptable with prerequisite "セッションベース認証を使用するシステム向け". The security principles are universal within the authentication domain. |
| パスワードポリシー | Conditionally Generic | Password policies apply to systems with password-based authentication. Not relevant to certificate-based authentication, API key systems, or passwordless authentication models. However, widely applicable across web, mobile, and enterprise applications. | Acceptable with prerequisite. Consider broadening title to "認証情報の強度要件" to cover passwords, PINs, biometric policies, etc. for wider applicability. |
| 権限の粒度設計 | Conditionally Generic | RBAC and ABAC are widely recognized access control models applicable across industries and system types. However, assumes multi-user systems with differentiated access needs. Not applicable to single-user applications or public read-only systems. | Acceptable with prerequisite "アクセス制御が必要なシステム向け". The concept transcends industry boundaries when authentication exists. |

#### Problem Bank Generality Evaluation
- Generic: 0 items (all conditionally generic)
- Conditionally Generic: 4 items (within authentication context, broadly applicable)
- Domain-Specific: 0 items

**Detailed analysis**:
- "MFAが未実装" - applicable to any system with user authentication across e-commerce, banking, healthcare, SaaS
- "セッションタイムアウトが無制限" - applies to web/mobile apps with session-based auth across industries
- "パスワードが平文で保存されている" - fundamental security issue applicable universally where passwords exist
- "全ユーザーに管理者権限が付与されている" - principle of least privilege violation applicable across all multi-user systems

All problems are authentication-domain issues without industry bias, applicable to healthcare portals, financial systems, e-commerce, and SaaS equally.

#### Improvement Proposals
- **Add Prerequisite Section**: At the beginning of the perspective, add: "この観点は **ユーザー認証機能を持つシステム** を対象としています。認証機能がないシステム(組込みファームウェア、バッチ処理ツール、データ処理パイプライン、スタンドアロンライブラリ等)には適用されません。"
- **Broaden Item 4**: Consider renaming "パスワードポリシー" to "認証情報の強度要件(パスワード、PIN、生体認証等)" to cover modern authentication methods beyond passwords.
- **OAuth/OIDC Note**: Add clarification that OAuth 2.0/OIDC are industry-standard protocols (not vendor-specific) to distinguish from proprietary solutions.

#### Confirmation (Positive Aspects)
- All 5 scope items use widely recognized authentication/authorization concepts (MFA, OAuth/OIDC, session security, password policies, RBAC/ABAC) that transcend industry boundaries.
- No dependencies on specific industries (finance, healthcare), regulations (PCI-DSS, HIPAA), or proprietary vendor technologies.
- OAuth 2.0 and OIDC are correctly chosen as standardized protocols rather than vendor-specific solutions (e.g., "Auth0 integration" or "AWS Cognito setup").
- Problem bank avoids industry-specific terminology - uses generic terms like "users", "sessions", "passwords", "admin privileges" applicable across domains.
- The perspective would produce meaningful results for 7+ out of 10 systems **that have user authentication** - web apps, mobile backends, SaaS platforms, enterprise portals, customer-facing APIs.
- Demonstrates best practice of focusing on security principles (MFA, least privilege, secure session handling) rather than compliance checklists.
- The conditionally generic classification is appropriate rather than problematic - authentication concerns naturally apply only to systems with authentication, which is a large and diverse category.
