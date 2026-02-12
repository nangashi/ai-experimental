### Generality Critique Results

#### Critical Issues (Domain over-dependency)
None

#### Scope Item Generality
| Item | Classification | Failed Dimensions | Proposal |
|------|----------------|------------------|----------|
| 1. 多要素認証(MFA)の実装 | Conditional | None (Generic within auth-enabled systems) | 前提条件明記: 「ユーザー認証機能を持つシステム」という前提を観点冒頭に記載 |
| 2. OAuth 2.0 / OIDC 対応 | Conditional | None (Widely adopted standard, conditional on external IdP integration) | 前提条件明記: OAuth/OIDCは広く採用されている技術標準 (REST, GraphQL同様)。外部IdP連携がある場合に適用。 |
| 3. セッション管理の安全性 | Conditional | None (Generic within session-based systems) | 前提条件明記: Webアプリケーション等のセッション管理を行うシステムに適用 |
| 4. パスワードポリシー | Conditional | None (Generic within password-based auth) | 前提条件明記: パスワード認証を採用するシステムに適用 |
| 5. 権限の粒度設計 | Conditional | None (Generic within multi-user systems) | 前提条件明記: 複数ユーザー・ロールを持つシステムに適用。RBAC/ABACはISO 9001, NIST等の標準に含まれる。 |

#### Problem Bank Generality
- Generic: 4 (全て条件付き汎用の範囲内)
- Conditional: 0
- Domain-Specific: 0

問題例の評価 (全て「ユーザー認証機能を持つシステム」という前提下で汎用):
- "MFAが未実装" - 認証システムに広く適用可能
- "セッションタイムアウトが無制限" - セッション管理システムに広く適用可能
- "パスワードが平文で保存されている" - パスワード認証システムに広く適用可能
- "全ユーザーに管理者権限が付与されている" - マルチユーザーシステムに広く適用可能

#### Improvement Proposals
- **観点冒頭に前提条件を明記**: 「本観点は **ユーザー認証機能を持つシステム** (Webアプリ、モバイルアプリ、API等) を対象とします。組込みファームウェア、バッチ処理、データ分析パイプライン等、認証機能を持たないシステムには適用されません。」
- **条件付き汎用の明示**: 各項目が「認証システム」「セッション管理システム」「外部IdP連携システム」などの条件下で汎用であることを明示。
- **OAuth 2.0 / OIDC の適切な評価**: OAuth 2.0とOIDCは広く採用されている技術標準 (RFC 6749, OpenID Connect Core 1.0) であり、REST APIやGraphQLと同様に業界横断的。特定プロトコル依存ではなく、認証・認可の共通標準として扱う。

#### Positive Aspects
- 全5項目が「ユーザー認証機能を持つシステム」という明確な条件下で、業界・規制非依存
- MFA、OAuth/OIDC、セッション管理、パスワードポリシー、RBAC/ABACは国際標準 (ISO 27001, NIST SP 800-63, OWASP) に基づく
- 問題バンクも認証システム全般に適用可能で、業界中立的
- B2Cアプリ、内部ツール、SaaS、API等の多様なシステムに適用可能 (ただし認証機能がある前提)
- **全体判断**: 条件付き汎用のため、観点名または冒頭に前提条件 (「ユーザー認証機能を持つシステム」) の明記を推奨。それ以外の改善は不要。
