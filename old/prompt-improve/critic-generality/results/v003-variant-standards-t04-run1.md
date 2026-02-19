### Generality Critique Results

#### Critical Issues (Domain over-dependency)
- **Item 1 "カート操作の整合性"**: "カート" is e-commerce-specific terminology - fails industry applicability (primarily retail/e-commerce)
- **Item 4 "配送先情報の検証"**: "配送先" and "郵便番号" are physical logistics-specific - fails industry applicability (not meaningful for SaaS, internal tools, digital-only services)
- **Problem Bank**: All 4 entries use e-commerce domain terminology (カート, 商品, 在庫, 配送先, 注文) - exceeds threshold (≥3 entries) for entry replacement

**Severity**: ≥2 domain-specific scope items detected - meets threshold for perspective redesign recommendation

#### Scope Item Generality
| Item | Classification | Failed Dimensions | Proposal |
|------|----------------|------------------|----------|
| 1. カート操作の整合性 | Domain-Specific | Industry (E-commerce) | Generalize to "一時保存データの整合性 - 一時的に保持されるユーザー選択データ（カート、下書き、設定変更等）が正確に反映されるか" |
| 2. 在庫引当のタイミング | Conditional | Industry (E-commerce, reservation systems) | Generalize to "リソース引当のタイミング - 有限リソース（在庫、座席、ライセンス等）の引当タイミングが明確か" |
| 3. 決済処理のエラーハンドリング | Conditional | Industry (Payment-enabled systems) | Retain as conditional generic - Applicable to finance, e-commerce, SaaS subscriptions, but requires payment functionality |
| 4. 配送先情報の検証 | Domain-Specific | Industry (Physical logistics) | Generalize to "外部データ整合性チェック - 外部参照データ（住所、組織ID、設定値等）の妥当性検証が実装されているか" |
| 5. 注文ステータスの状態遷移 | Generic | None | Generalize terminology only: "処理ステータスの状態遷移 - 処理の状態遷移（受付→処理中→完了）が正しく設計されているか" |

#### Problem Bank Generality
- Generic: 0
- Conditional: 0
- Domain-Specific: 4 (list: "カートに追加した商品が消失する", "在庫切れ商品が購入可能になっている", "配送先の郵便番号が不正でもエラーにならない", "キャンセル済み注文が発送されてしまう")

**Problem Bank Analysis**:
- **カート/商品**: E-commerce-specific, should abstract to "一時保存データ" or "リクエスト項目"
- **在庫切れ**: Retail-specific, should generalize to "リソース枯渇状態"
- **配送先/郵便番号**: Physical logistics-specific, should abstract to "外部参照データの妥当性"
- **発送**: Physical fulfillment-specific, should generalize to "処理実行"

#### Improvement Proposals
- **Proposal 1 (Critical)**: **Perspective Redesign** - 2 scope items exhibit e-commerce over-dependency (Item 1: カート, Item 4: 配送先). Recommend perspective rename: "注文処理の正確性" → "トランザクション処理の正確性" with generalized scope.
- **Proposal 2**: Replace Item 1 - "カート操作の整合性" → "一時保存データの整合性 - セッションやドラフト状態のデータが操作を通じて正確に保持されるか"
- **Proposal 3**: Generalize Item 2 - "在庫引当" → "リソース引当" (abstract to resource allocation pattern applicable to inventory, seats, licenses, API quotas)
- **Proposal 4**: Retain Item 3 as conditional generic - "決済処理" is common enough (SaaS billing, marketplace payments) to be conditionally generic, but note prerequisite: "決済機能を持つシステム"
- **Proposal 5**: Replace Item 4 - "配送先情報の検証" → "外部参照データの整合性チェック - 郵便番号、組織コード、設定値等の外部データとの整合性検証"
- **Proposal 6**: Update Item 5 terminology - "注文ステータス" → "処理ステータス" (keep state machine concept, remove order-specific wording)
- **Proposal 7**: Replace all Problem Bank entries:
  - "カートに追加した商品が消失する" → "一時保存データの選択項目が消失する"
  - "在庫切れ商品が購入可能になっている" → "リソース枯渇状態でリクエストが受理されている"
  - "配送先の郵便番号が不正でもエラーにならない" → "外部参照データの妥当性チェックが未実装"
  - "キャンセル済み注文が発送されてしまう" → "キャンセル済み処理が実行されてしまう"

#### Positive Aspects
- Item 2 "在庫引当" and Item 5 "状態遷移" contain valuable abstractions (resource allocation timing, state machine design) applicable beyond e-commerce
- Underlying concerns (data consistency, timing control, error handling, validation, state management) are universal software engineering principles
- With terminology abstraction, perspective can serve finance (transaction processing), healthcare (appointment management), SaaS (license allocation), and internal tools (workflow management)
