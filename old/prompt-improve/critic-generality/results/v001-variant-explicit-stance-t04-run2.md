### Generality Critique Results

#### Critical Issues (Perspective overly dependent on specific domains)
- **Issue**: 2 out of 5 scope items are e-commerce domain-specific, meeting the threshold for perspective redesign.
- **Reason**: Items 1 and 4 use terminology specific to online retail (cart, shipping address, postal code validation) that cannot be meaningfully applied to internal tools, data pipelines, or OSS libraries. The "7 out of 10 projects" test fails.

#### Scope Item Generality Evaluation
| Scope Item | Classification | Reason | Improvement Proposal |
|------------|----------------|--------|---------------------|
| カート操作の整合性 | Domain-Specific | "Cart" is specific to e-commerce and online retail. Not applicable to HR systems, analytics platforms, or IoT applications. Tested on internal admin tool (no cart concept), data processing pipeline (irrelevant), mobile social app (irrelevant). | Generalize to "一時データ集合の操作整合性" or "ユーザーセッション内データの整合性管理" to cover temporary data collections in various contexts (shopping carts, form drafts, comparison lists). |
| 在庫引当のタイミング | Conditionally Generic | While "在庫" (inventory) suggests e-commerce, the underlying concept of "resource reservation timing" applies to booking systems, seat reservations, license allocation, and resource scheduling across domains. | Replace "在庫引当" with "リソース引当" to generalize. Applicable to hotel booking, appointment scheduling, cloud resource allocation, license management. |
| 決済処理のエラーハンドリング | Conditionally Generic | Payment processing is not limited to e-commerce - applies to SaaS billing, subscription management, in-app purchases, donation platforms, and various business systems. However, systems without payment features cannot use this. | Retain with prerequisite note "決済機能を持つシステム向け". Rename to "外部システム連携のエラーハンドリング(決済等)" for broader applicability. |
| 配送先情報の検証 | Domain-Specific | Shipping address and postal code validation are specific to physical goods delivery (e-commerce, logistics). Not applicable to SaaS, data platforms, or most software systems. Tested on cloud storage service (no shipping), CRM system (irrelevant), video streaming app (irrelevant). | Generalize to "ユーザー入力情報の妥当性検証" or "構造化データの整合性チェック" to cover form validation, address verification, data quality checks across domains. |
| 注文ステータスの状態遷移 | Conditionally Generic | "Order status" suggests e-commerce, but state transition management is universal - applies to approval workflows, ticket systems, CI/CD pipelines, and process orchestration. | Replace "注文" with "処理" to generalize: "処理ステータスの状態遷移設計". Covers job processing, request handling, task management across domains. |

#### Problem Bank Generality Evaluation
- Generic: 0 items
- Conditionally Generic: 0 items
- Domain-Specific: 4 items (all problems are e-commerce-specific)

**Specific domain-specific problems**:
- "カートに追加した商品が消失する" - uses "cart" and "product" (e-commerce terms)
- "在庫切れ商品が購入可能になっている" - "inventory" and "purchase" are e-commerce-specific
- "配送先の郵便番号が不正でもエラーにならない" - "shipping address" and "postal code" are logistics-specific
- "キャンセル済み注文が発送されてしまう" - "order", "cancellation", and "shipment" are e-commerce/logistics terms

The problem bank is entirely oriented toward online retail scenarios and cannot be applied meaningfully to B2B SaaS, internal tools, or data processing systems.

#### Improvement Proposals
- **Scope Item 1**: Replace "カート操作の整合性" with "一時データ集合の操作整合性(追加・削除・変更の正確な反映)" to cover shopping carts, form drafts, workspace items, comparison lists across domains.
- **Scope Item 2**: Generalize "在庫引当のタイミング" to "リソース引当のタイミング" to cover inventory, seats, appointments, licenses, compute resources.
- **Scope Item 3**: Acceptable as conditionally generic but add prerequisite "決済機能を持つシステム向け" or broaden to "外部システム連携(決済・通知等)のエラーハンドリング".
- **Scope Item 4**: Replace "配送先情報の検証" with "構造化入力データの妥当性検証" to cover address validation, date ranges, data format checks, cross-field validation.
- **Scope Item 5**: Change "注文ステータス" to "処理ステータス" to generalize: "処理ステータスの状態遷移(受付→処理中→完了等)".
- **Problem Bank - Wholesale Replacement**: Replace all 4 e-commerce examples with domain-neutral alternatives:
  - "カートに追加した商品が消失する" → "一時保存されたデータが消失する"
  - "在庫切れ商品が購入可能になっている" → "利用不可能なリソースが予約可能になっている"
  - "配送先の郵便番号が不正でもエラーにならない" → "入力データの妥当性チェックが機能していない"
  - "キャンセル済み注文が発送されてしまう" → "中止済み処理が実行されてしまう"
- **Perspective Redesign**: Strongly recommend renaming from "注文処理の正確性" to "データ処理の正確性" or "ワークフロー処理の整合性" to signal domain independence.

#### Confirmation (Positive Aspects)
- Items 2, 3, and 5 contain generalizable core concepts (resource reservation, error handling, state transitions) that are valuable across domains once reframed.
- The perspective correctly identifies important data consistency and workflow integrity concerns, which are universal needs.
- The state transition concept (item 5) is particularly well-chosen as a fundamental pattern applicable across many system types.
