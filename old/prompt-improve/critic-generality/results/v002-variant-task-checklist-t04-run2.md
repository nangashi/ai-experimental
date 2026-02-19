### Generality Critique Results

#### Critical Issues (Domain over-dependency)
- Multiple e-commerce-specific items detected (カート操作, 在庫引当, 配送先情報)
- Problem bank entirely focused on e-commerce domain (商品, カート, 配送先)
- Threshold met: ≥2 domain-specific scope items → Perspective redesign recommended

#### Scope Item Generality
| Item | Classification | Failed Dimensions | Proposal |
|------|----------------|------------------|----------|
| 1. カート操作の整合性 | Domain-Specific | Industry Applicability | Replace "カート" with generic concept "一時的な選択状態" or "作業中データ" - e.g., "作業中データの整合性 - ユーザーの操作（追加・削除・変更）が正確に反映されるか" |
| 2. 在庫引当のタイミング | Conditionally Generic | Industry Applicability (4-6/10) | Generalize to "リソース引当のタイミング - リソース（座席、在庫、予約枠等）の引当タイミングが明確か" - applicable to booking, reservation, inventory systems |
| 3. 決済処理のエラーハンドリング | Conditionally Generic | Industry Applicability (5-7/10) | Keep as "外部決済処理のエラーハンドリング" but note prerequisite: "決済機能を持つシステム". Applicable beyond e-commerce (SaaS billing, ticketing, donations) |
| 4. 配送先情報の検証 | Domain-Specific | Industry Applicability, Technology Stack | Replace with generic validation concept: "外部入力データの検証 - 住所、電話番号等の入力データの整合性チェックが実装されているか" -郵便番号は日本特化 |
| 5. 注文ステータスの状態遷移 | Conditionally Generic | Industry Applicability (5-7/10) | Generalize to "処理ステータスの状態遷移 - 処理の状態遷移（受付→処理中→完了）が正しく設計されているか" - applicable to workflow systems, request processing |

#### Problem Bank Generality
- Generic: 0
- Conditional: 0
- Domain-Specific: 4 (list: all entries)

**Detailed Analysis:**
- "カートに追加した商品が消失する" → "作業中データが予期せず消失する"
- "在庫切れ商品が購入可能になっている" → "利用不可リソースが引当可能になっている"
- "配送先の郵便番号が不正でもエラーにならない" → "入力データの整合性チェックが機能していない"
- "キャンセル済み注文が発送されてしまう" → "無効化された処理が実行されてしまう"

**Industry Neutrality Test:**
- Current items fail to apply meaningfully to: Internal tools (approval workflows), OSS libraries (API clients), B2B SaaS (subscription management without physical goods)

#### Improvement Proposals
- Perspective Redesign: Rename to "状態管理と整合性観点" or "トランザクション処理の正確性観点" to remove e-commerce focus
- Item 1: Replace with generic temporary state management concept applicable to forms, wizards, draft documents
- Item 4: Remove "配送先" and "郵便番号" specifics - focus on generic input validation patterns
- Problem Bank: Complete rewrite using domain-neutral terminology (作業データ, リソース, 処理ステータス, 入力検証)

#### Positive Aspects
- Items 2, 3, 5 contain generalizable concepts (resource allocation, external service error handling, state transitions) beneath the e-commerce-specific surface
- Core concern (data consistency in multi-step processes) is universally valuable
