### Generality Critique Results

#### Critical Issues (Domain over-dependency)
None

#### Scope Item Generality
| Item | Classification | Failed Dimensions | Proposal |
|------|----------------|------------------|----------|
| 1. 多要素認証(MFA)の実装 | Conditional Generic | Industry Applicability (認証機能を持つシステム限定) | 前提条件「ユーザー認証機能を持つシステム」を観点冒頭に明記 |
| 2. OAuth 2.0 / OIDC 対応 | Conditional Generic | Technology Stack (広く採用されている標準だが、外部IdP連携前提) | 前提条件「外部IdP連携を行うシステム」を明記、または「外部認証プロバイダ連携」として一般化 |
| 3. セッション管理の安全性 | Conditional Generic | Industry Applicability (セッション管理を行うシステム限定) | 前提条件「セッションベース認証を採用するシステム」を明記 |
| 4. パスワードポリシー | Conditional Generic | Industry Applicability (パスワード認証を持つシステム限定) | 前提条件「パスワード認証を採用するシステム」を明記 |
| 5. 権限の粒度設計 | Conditional Generic | Industry Applicability (アクセス制御が必要なシステム限定) | 前提条件「アクセス制御を持つシステム」を明記 |

#### Problem Bank Generality
- Generic: 4（条件付きだが、ユーザー認証機能を持つシステムには広く適用可能）
- Conditional: 0
- Domain-Specific: 0

すべての問題例（MFA未実装、セッションタイムアウト無制限、パスワード平文保存、全ユーザー管理者権限）が、認証機能を持つシステムに広く適用可能。業界・技術スタック依存なし。

#### Improvement Proposals
- **観点全体が「ユーザー認証・認可機能を持つシステム」という前提で条件付き汎用**
- 観点名または導入部に前提条件を明記: 「本観点は、ユーザー認証・認可機能を持つシステムに適用されます。組込みシステム、バッチ処理、データ処理パイプライン等の認証機能を持たないシステムには適用されません。」
- 項目2のOAuth 2.0 / OIDCは広く採用されている技術標準であり、特定ベンダー依存ではないため汎用性は高い（ただし外部IdP連携を行うシステム限定）
- 前提条件を明記することで、適用可能性の範囲を明確化し、誤った適用を防ぐ

#### Positive Aspects
- 全5項目がユーザー認証・認可機能を持つシステム（Webアプリ、モバイルアプリ、SaaS、内部管理ツール等）に広く適用可能
- 業界依存（金融、医療等）や地域規制依存（GDPR、HIPAA等）がない
- OAuth 2.0 / OIDCは業界標準プロトコルであり、Google、Microsoft、GitHub等の複数IdPに対応可能
- RBAC/ABACは広く採用されているアクセス制御モデルで、特定技術スタックに依存しない
- 問題バンクも認証・認可の一般的な脆弱性をカバーしており、業界非依存
- MFA、セッション管理、パスワードポリシーなどの認証セキュリティ基本原則が適切にカバーされている
- 前提条件を明記すれば、この観点は幅広いプロジェクトで活用可能
