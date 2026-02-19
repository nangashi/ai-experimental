### Generality Critique Results

#### Critical Issues (Perspective overly dependent on specific domains)
- **Issue**: The perspective contains 2 clearly domain-specific scope items out of 5 total items (items 1 and 4), exceeding the "2 or more domain-specific items" threshold requiring perspective redesign.
- **Reason**: Testing across 10 random projects (HR management system, data analytics dashboard, IoT device management platform, social media app, content management system, internal wiki, video streaming service, booking system, API gateway, developer tools) would yield meaningful results for only 2-3 projects (those involving shopping/ordering workflows). The e-commerce-specific terminology creates a narrow applicability window.

#### Scope Item Generality Evaluation
| Scope Item | Classification | Reason | Improvement Proposal |
|------------|----------------|--------|---------------------|
| カート操作の整合性 | Domain-Specific | "カート" (shopping cart) is specific to e-commerce/retail. Testing across 3 contexts: e-commerce site (meaningful), project management tool (not meaningful—no cart concept), analytics dashboard (not meaningful). Fails "7 out of 10 projects" test. Only retail, food delivery, and similar purchasing systems have carts. | Replace with "一時データコレクションの整合性 - 一時的なデータセット（選択リスト、ドラフト、作業キュー等）への追加・削除・変更操作が正確に反映されるか。" This generalizes to temporary data manipulation across diverse contexts (form drafts, playlist editing, task selection, configuration builders). |
| 在庫引当のタイミング | Conditionally Generic | While "在庫" (inventory) suggests e-commerce, the underlying concept of "resource allocation timing" is more broadly applicable. Testing across 3 contexts: e-commerce (meaningful—product inventory), hotel booking system (meaningful—room availability), cloud resource provisioning (meaningful—compute allocation). Generalizable to any system managing limited resources with reservation/allocation workflows. | Replace with "リソース引当のタイミング設計 - 限定的なリソース（在庫、座席、予約枠、クレジット等）の引当タイミング（仮予約時/確定時/支払完了時）が明確に定義されているか。" This preserves the core timing/consistency concept while broadening applicability. |
| 決済処理のエラーハンドリング | Conditionally Generic | Payment processing is not limited to e-commerce (applies to subscription services, fintech, donation platforms, ticketing systems, B2B invoicing). However, many projects do not involve payments (internal tools, analytics platforms, content systems, IoT management). Testing across 3 contexts: SaaS subscription platform (meaningful), open-source library (not meaningful), social media app without monetization (not meaningful). Applicable to payment-enabled systems across industries. | Acceptable as conditionally generic with prerequisite clarification: "決済機能を持つシステムに適用" (applies to systems with payment functionality). Alternative for broader scope: generalize to "外部サービス連携のエラーハンドリング - 外部API/サービスとの連携失敗時のリトライ・ロールバック・補償処理が設計されているか。" |
| 配送先情報の検証 | Domain-Specific | "配送先" (shipping/delivery address) and "郵便番号" (postal code) validation are specific to physical goods delivery in e-commerce/logistics. Testing across 3 contexts: e-commerce with physical shipping (meaningful), SaaS application (not meaningful—no shipping), mobile game (not meaningful). Digital services, APIs, internal tools, data platforms do not have shipping addresses. | Consider two approaches: (1) Generalize to "住所データの妥当性検証 - 住所情報の整合性チェック（郵便番号と住所の対応、形式検証等）が実装されているか。" This broadens to any system collecting addresses (billing, user profiles, service area checks). (2) Delete if too narrow even after generalization. |
| 注文ステータスの状態遷移 | Conditionally Generic | While "注文" (order) suggests e-commerce, the underlying concept of "request/transaction lifecycle state machines" is broadly applicable. Testing across 3 contexts: e-commerce order (meaningful), support ticket system (meaningful—ticket states), job processing pipeline (meaningful—job status). The state transition concept applies to workflow systems, approval processes, task management, subscription lifecycle. | Replace with "処理ステータスの状態遷移設計 - 処理リクエストの状態遷移（受付→処理中→完了/キャンセル/エラー）が正しく定義され、不正な遷移が防止されているか。" This abstracts to general state machine validation across diverse workflow systems. |

#### Problem Bank Generality Evaluation
- Generic: 0 items
- Conditionally Generic: 0 items
- Domain-Specific: 4 items (list specifically: all 4 problem examples)

All 4 problem bank entries contain e-commerce-specific terminology:
1. "カートに追加した商品が消失する" - "カート" (cart) and "商品" (product) are e-commerce terms. Testing across 3 contexts: online store (meaningful), project management tool (not meaningful), data pipeline (not meaningful).
2. "在庫切れ商品が購入可能になっている" - "在庫" (inventory), "商品" (product), "購入" (purchase) are retail-specific. Not applicable to non-inventory systems.
3. "配送先の郵便番号が不正でもエラーにならない" - "配送先" (shipping address) assumes physical delivery context.
4. "キャンセル済み注文が発送されてしまう" - "注文" (order) and "発送" (shipment) are e-commerce/logistics terms.

Generalization proposals:
1. "一時選択データに追加した項目が消失する" (Items added to temporary selection data disappear) or "ドラフトデータの変更が保存されない" (Draft data changes not persisted)
2. "利用不可能なリソースが予約可能な状態になっている" (Unavailable resources shown as reservable) or "引当済みリソースが重複予約されている" (Allocated resources double-booked)
3. "住所データの郵便番号フォーマットが検証されていない" (Postal code format in address data not validated) or "入力データの整合性チェックが不足" (Input data consistency checks insufficient)
4. "キャンセル済み処理が実行継続されている" (Cancelled processing continues execution) or "状態遷移の整合性が保証されていない" (State transition consistency not guaranteed)

#### Improvement Proposals
- **Complete perspective redesign required**: With 2 clearly domain-specific scope items (40% of evaluation criteria), 2 conditionally generic items requiring clarification, and 4 domain-specific problem examples (100% of problem bank), this perspective is too narrowly tailored to e-commerce contexts.
- **Perspective renaming**: Rename from "注文処理の正確性観点" to a domain-neutral title such as "データ整合性観点" (Data Consistency Perspective) or "トランザクション処理の正確性観点" (Transaction Processing Accuracy Perspective).
- **Scope Item 1 - Replace**: Completely rewrite using temporary data collection/draft data concept applicable across form builders, configuration tools, playlist editors, selection interfaces, shopping carts, batch operation builders.
- **Scope Item 2 - Generalize**: Reframe from inventory to generic resource allocation (seats, credits, capacity, inventory, appointments, licenses).
- **Scope Item 3 - Clarify or Generalize**: Either (a) add prerequisite "決済機能を持つシステムに適用" or (b) generalize to external service integration error handling for broader scope.
- **Scope Item 4 - Generalize or Delete**: Either (a) generalize to generic address validation (applicable to billing, shipping, user profiles, service area verification) or (b) delete if considered too narrow even after generalization. Address validation is relevant to many but not all systems.
- **Scope Item 5 - Generalize**: Reframe from order status to generic state machine validation for workflow systems, approval processes, job processing, request handling.
- **Problem Bank - Complete Overhaul**: Replace all 4 e-commerce examples with domain-neutral problems:
  - "一時データへの変更が消失する" (Changes to temporary data disappear)
  - "利用不可能なリソースが予約可能になっている" (Unavailable resources shown as available)
  - "入力データの整合性検証が不足している" (Input data consistency validation insufficient)
  - "不正な状態遷移が許可されている" (Invalid state transitions allowed)

#### Confirmation (Positive Aspects)
- Items 2, 3, and 5 contain valuable underlying concepts (resource allocation, error handling, state machines) that are generalizable beyond e-commerce once terminology is abstracted.
- The focus on data consistency, state transition correctness, and error handling represents important design concerns applicable across diverse system types (booking platforms, workflow engines, subscription services, approval systems, job processing).
- The problem bank structure (data loss, resource conflicts, validation gaps, state inconsistencies) represents common correctness anti-patterns once domain-specific language is removed.
- With generalization, this perspective could provide meaningful evaluation across booking systems, workflow applications, approval processes, resource management platforms, subscription services, task processing systems, and yes, e-commerce platforms.
