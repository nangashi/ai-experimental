### Generality Critique Results

#### Critical Issues (Domain over-dependency)
None

#### Scope Item Generality
| Item | Classification | Failed Dimensions | Proposal |
|------|----------------|------------------|----------|
| 1. 多要素認証(MFA)の実装 | Conditionally Generic | Industry (ユーザー認証前提) | 前提条件「ユーザー認証機能を持つシステム」の明記を推奨。該当システムには広く適用可能。 |
| 2. OAuth 2.0 / OIDC 対応 | Conditionally Generic | Industry (ユーザー認証前提) | OAuth/OIDCは広く採用された技術標準であり、汎用性あり。外部IdP連携がある前提を明記。 |
| 3. セッション管理の安全性 | Conditionally Generic | Industry (ユーザー認証前提) | セッションベース認証を採用するシステムに適用。前提条件の明記を推奨。 |
| 4. パスワードポリシー | Conditionally Generic | Industry (ユーザー認証前提) | パスワード認証を採用するシステムに適用。前提条件の明記を推奨。 |
| 5. 権限の粒度設計 | Conditionally Generic | Industry (ユーザー認証前提) | RBAC/ABACは広く認知された汎用パターン。アクセス制御がある前提を明記。 |

#### Problem Bank Generality
- Generic: 0（認証前提のため）
- Conditional: 4（全てユーザー認証機能前提）
- Domain-Specific: 0

問題例（MFA未実装、セッションタイムアウト無制限、パスワード平文保存、全ユーザーに管理者権限）は、ユーザー認証機能を持つシステムに広く適用可能。業界非依存。

#### Improvement Proposals
- **観点名または導入部で前提条件を明記**: 「本観点は、ユーザー認証機能を持つシステムを対象とする。該当しないシステム（組込みファームウェア、バッチ処理、認証不要のパブリックAPI等）には適用不要。」
- **適用範囲の明示**: 以下のシステムには適用可能
  - Webアプリケーション（B2C、B2B、SaaS）
  - モバイルアプリ
  - 社内業務システム
  - 管理コンソール
- **適用外の例**: 組込みシステム、データ処理パイプライン、認証不要の公開API、IoTデバイス（一部）

#### Positive Aspects
- **技術標準の適切な選定**: OAuth 2.0 / OIDCは業界横断的に採用されている認証標準であり、特定ベンダー依存ではない。
- **セキュリティ基本原則のカバー**: MFA、セッション管理、パスワードポリシー、権限粒度はユーザー認証のベストプラクティスとして確立。
- **業界非依存**: 金融、医療、EC、SaaS等、ユーザー認証があるあらゆる業界に適用可能。
- **規制中立**: 特定規制（HIPAA、PCI-DSS等）への言及なし。
- **技術スタック非依存**: 特定のフレームワーク・クラウドサービスへの依存なし。

前提条件を明記すれば、条件付き汎用として適切に機能する観点定義。
