### Generality Critique Results

#### Critical Issues (Domain over-dependency)
- E-commerce over-specialization: Items 1, 3, 4 and entire problem bank use e-commerce-specific terminology (カート, 在庫, 配送先, 商品), limiting applicability to non-retail systems
- **Severity**: 2+ domain-specific scope items detected → **Perspective redesign recommended**

#### Scope Item Generality
| Item | Classification | Failed Dimensions | Proposal |
|------|----------------|------------------|----------|
| 1. カート操作の整合性 | Domain-Specific | Industry Applicability | Replace with "一時的な選択状態の整合性 - ユーザーの選択操作(追加・削除・変更)が正確に反映されるか" to generalize beyond shopping cart concept |
| 2. 在庫引当のタイミング | Conditionally Generic | Industry Applicability (passes 2/3) | Replace with "リソース引当のタイミング - 限定リソースの引当タイミング(選択時/確定時/処理完了時)が明確か" - applicable to seat reservation, appointment booking, resource allocation systems |
| 3. 決済処理のエラーハンドリング | Conditionally Generic | Industry Applicability (passes 2/3) | Keep payment terminology but recognize it's conditional on "systems with payment transactions" (e-commerce, SaaS billing, booking platforms). Alternatively: "重要な外部連携処理のエラーハンドリング" for full generality |
| 4. 配送先情報の検証 | Domain-Specific | Industry Applicability | Replace with "宛先情報の検証 - 出力先情報の形式・整合性チェックが実装されているか" to cover delivery addresses, email recipients, API endpoints, etc. |
| 5. 注文ステータスの状態遷移 | Conditionally Generic | Industry Applicability (passes 2/3) | Replace with "処理ステータスの状態遷移 - 処理の状態遷移(受付→処理中→完了)が正しく設計されているか" to apply beyond order processing to job workflows, approval processes, etc. |

#### Problem Bank Generality
- Generic: 0
- Conditional: 0
- Domain-Specific: 4 (all problem examples)
  - "カートに追加した商品が消失する" - shopping cart terminology
  - "在庫切れ商品が購入可能になっている" - inventory/purchase terminology
  - "配送先の郵便番号が不正でもエラーにならない" - delivery address terminology
  - "キャンセル済み注文が発送されてしまう" - order/shipment workflow terminology

All 4 problem examples are tightly coupled to e-commerce domain.

#### Improvement Proposals
- **Scope Item 1**: "一時的な選択状態の整合性" - generalizes cart concept to temporary user selections in any multi-step workflow
- **Scope Item 2**: "リソース引当のタイミング" - applicable to seat reservations, meeting room bookings, limited-edition items, API rate limits
- **Scope Item 3**: Consider two options:
  - Keep as conditional-generic with clear prerequisite: "決済機能を持つシステムにおける決済処理のエラーハンドリング"
  - Fully generalize to "重要な外部連携処理のエラーハンドリング - 外部API呼び出し失敗時のリトライ・ロールバック処理"
- **Scope Item 4**: "宛先情報の検証 - 出力先の形式と整合性チェック(住所、メールアドレス、API endpoint等)"
- **Scope Item 5**: "処理ステータスの状態遷移 - ワークフローの状態管理が正しく設計されているか"
- **Problem Bank**: Complete rewrite needed:
  - "一時選択データが消失する"
  - "既に引当済みのリソースが重複予約可能になっている"
  - "宛先情報の形式検証が不十分でエラーにならない"
  - "キャンセル済みの処理が実行されてしまう"
- **Overall recommendation**: Given 2 domain-specific + 2 conditionally generic items with e-commerce bias, and 100% e-commerce problem bank, this perspective requires **full redesign** to establish domain-neutral framing. Consider renaming perspective from "注文処理の正確性" to "トランザクション処理の正確性" or "ワークフロー整合性"

#### Positive Aspects
- Item 5 (state transition design) concept is fundamentally generic - state machines apply broadly
- Item 2 captures important resource allocation timing concern, which is generalizable
- Item 3 recognizes importance of idempotency and rollback, which are universal distributed systems concerns
