### Generality Critique Results

#### Critical Issues (Domain over-dependency)
- **Item 1: HIPAA準拠の患者データ保護** - HIPAAは米国医療業界特有の規制。PHI (Protected Health Information) という医療業界専門用語を使用。
- **Item 2: GDPR対応の同意管理** - GDPRは欧州地域の規制。他地域では直接適用されない。
- **Problem Bank全体** - PHI、患者、診療記録、処方箋など、全ての問題例が医療業界に特化した用語を使用。

#### Scope Item Generality
| Item | Classification | Failed Dimensions | Proposal |
|------|----------------|------------------|----------|
| 1. HIPAA準拠の患者データ保護 | Domain-Specific | Industry (healthcare), Regulation (US-specific HIPAA) | 汎用化: "個人データの保護方針" - 取り扱う個人データが適切に保護されているか |
| 2. GDPR対応の同意管理 | Conditional | Regulation Dependency (EU-specific, but consent is common standard) | 汎用化: "データ処理の同意管理" - 個人データ処理に対するユーザー同意の取得・管理が設計されているか (GDPR, CCPA等の共通原則) |
| 3. アクセス権限の最小化原則 | Generic | None | そのまま維持。最小権限の原則はISO 27001等の国際標準に含まれる |
| 4. データ保持期間の明確化 | Generic | None | そのまま維持。データライフサイクル管理は業界横断的要件 |
| 5. 匿名化・仮名化の実装 | Generic | None | そのまま維持。プライバシー保護の共通技術 |

#### Problem Bank Generality
- Generic: 0
- Conditional: 0
- Domain-Specific: 3 (全て医療業界用語)
  - "PHI が暗号化されていない" → "個人データが暗号化されていない"
  - "患者の診療記録が無期限に保存されている" → "個人データが無期限に保存されている"
  - "処方箋情報が複数部署で共有されている" → "機密データが過度に共有されている"

#### Improvement Proposals
- **観点全体の再設計を推奨**: 特定領域依存が2項目以上 (Item 1, 2) あり、閾値を超過。観点名を "プライバシー観点" から "個人データ保護観点" に変更することも検討。
- **Item 1の汎用化**: HIPAA/PHI/患者という医療用語を全て削除し、「個人データの保護方針」として再定義。
- **Item 2の修正**: GDPRという特定規制名を削除し、「データ処理の同意管理」として共通原則 (GDPR, CCPA, LGPD等) に基づく説明に変更。参考として複数の標準/規制を列挙することは可能だが、特定規制名を項目名に含めない。
- **Problem Bank全面改訂**: 全ての医療用語を業界中立な表現 (個人データ、機密データ、ユーザー等) に置換。

#### Positive Aspects
- 項目3-5は業界・規制非依存で優れた汎用性を持つ
- 最小権限原則、データ保持期間、匿名化は国際標準 (ISO 27001, ISO 29100) に基づく
- 観点の基本構造 (5項目+問題バンク) は適切で、内容の差し替えで汎用化可能
