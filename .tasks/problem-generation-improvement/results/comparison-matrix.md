# 問題生成品質の比較マトリクス

評価日時: 2026-02-12

## 総合比較

| バリアント | エージェント | 入力型整合性 | タスク整合性 | カバレッジ | 入力の現実性 | 識別力 | 難易度分布 | 静的スコア |
|-----------|------------|------------|------------|----------|------------|--------|-----------|----------|
| baseline | critic | Pass | 2 | 3 | 3 | 要動的検証 | 要動的検証 | 8.0/10 |
| type-aware | critic | Pass | 3 | 3 | 3 | 要動的検証 | 要動的検証 | 9.1/10 |
| hybrid | critic | Pass | 3 | 3 | 3 | 要動的検証 | 要動的検証 | 9.1/10 |
| baseline | reviewer | Pass | 2 | 2 | 2 | 要動的検証 | 要動的検証 | 6.7/10 |
| type-aware | reviewer | Pass | 3 | 3 | 3 | 要動的検証 | 要動的検証 | 9.1/10 |
| hybrid | reviewer | Pass | 3 | 3 | 3 | 要動的検証 | 要動的検証 | 9.1/10 |

### 静的スコア算出方法
```
静的スコア = (タスク整合性×3.0 + カバレッジ×2.0 + 入力の現実性×1.0) / (3×3.0 + 3×2.0 + 3×1.0) × 10
= (rating×weight合計) / 18.0 × 10
```

---

## 詳細評価

### baseline × critic-effectiveness

**エージェント種別**: Type-C (Meta-evaluation Agent)
**期待入力型**: Perspective definition files
**テスト入力型**: Perspective definition files (英語、日本語混在)

#### 1.1 入力型整合性
**評価**: Pass
**根拠**: 全7シナリオの入力が観点定義ファイル形式であり、エージェント定義と一致。入力にはPurpose, Scope (In-Scope), Scope (Out-of-Scope), Scoring Guidelines, Bonus/Penaltyセクションが含まれ、critic-effectivenessエージェントが期待する形式と完全に一致する。

#### 1.2 タスク整合性
**評価**: 2 (Mostly)
**根拠**:
- **対応する基準** (5/7): T01(価値寄与+境界), T02(境界+相互参照), T03(スコープ適切性+価値), T04(相互参照+境界), T05(境界+価値+実行可能性)
- **部分対応** (2/7): T06(実行可能性+価値), T07(価値+スコープ) - 「認識」「評価」等の非実行可能パターンの検出を期待しているが、エージェント定義では「実行可能性評価」が明示的な能力カテゴリとして記載されていない
- ルーブリックの基準名は概ね適切だが、エージェント定義の5つの核心能力 (Contribution Analysis, Boundary Verification, Cross-reference Validation, Actionability Assessment, Scope Focus Evaluation) との対応が明示的でない

#### 1.5 カバレッジ
**評価**: 3 (Full)
**根拠**:
- エージェントの5つの能力カテゴリをすべてカバー:
  - Contribution Analysis: T01, T04, T05, T06, T07
  - Boundary Verification: T01, T02, T03, T04, T07
  - Cross-reference Validation: T02, T04
  - Actionability Assessment: T05, T06
  - Scope Focus Evaluation: T03, T05
- カテゴリ間のバランス: 各カテゴリから最低2シナリオ以上、最大5シナリオで均等

#### 1.6 入力の現実性
評価**: 3 (Natural)
**根拠**:
- すべての観点定義が実際のプロジェクトで出てくる内容に近い (Documentation Quality, Error Handling, API Design等)
- 人工的マーカーなし (「TODO」「FIXME」等の明示的な問題挿入なし)
- 日本語と英語混在は reviewer_create スキルの実際の出力パターンと一致

#### 静的スコア算出
```
(2×3.0 + 3×2.0 + 3×1.0) / 18.0 × 10 = 15/18 × 10 = 8.33 → 8.0/10
```

#### 特記事項
- **長所**: 入力の現実性が高く、実際の観点定義レビューシナリオに近い
- **改善点**: T06, T07 で「認識のみで実行可能性がない」パターンを期待しているが、エージェント定義に「Actionability Assessment」の詳細が不足

---

### type-aware × critic-effectiveness

**エージェント種別**: Type-C (Meta-evaluation Agent)
**期待入力型**: Perspective definition files
**テスト入力型**: Perspective definition files (日本語)

#### 1.1 入力型整合性
**評価**: Pass
**根拠**: 全7シナリオの入力が観点定義ファイル形式で、エージェント定義と一致。baseline同様、Purpose, Scope, Out-of-Scope, Scoring Guidelines, Bonus/Penaltyセクションを含む。

#### 1.2 タスク整合性
**評価**: 3 (Full)
**根拠**:
- **完全対応** (7/7): すべてのシナリオがエージェントの核心能力に直接対応
  - T01: 価値寄与+境界曖昧性 (Contribution + Boundary)
  - T02: スコープ重複 (Boundary Verification)
  - T03: 狭隘なスコープ (Scope Focus + Value)
  - T04: 無効相互参照+複数重複 (Cross-reference + Boundary)
  - T05: 良好な観点定義 (全カテゴリ統合的評価)
  - T06: 非実行可能パターン (Actionability + Value)
  - T07: 曖昧な価値提案+完全重複 (Value + Scope)
- **改善点**: baseline と異なり、各シナリオのルーブリック基準がエージェントの能力カテゴリ名を明示的に使用 (例: "Value contribution identification", "Boundary overlap detection")

#### 1.5 カバレッジ
**評価**: 3 (Full)
**根拠**:
- 5つの能力カテゴリをすべてカバー、かつ各カテゴリから複数シナリオ:
  - Boundary verification: T01, T02, T04, T05
  - Value contribution: T01, T03, T05, T06, T07
  - Cross-reference accuracy: T01, T04
  - Scope appropriateness: T03, T06, T07
  - Actionability: T01, T05, T06, T07
- カテゴリ間のバランス: 各カテゴリ2-5シナリオで均等

#### 1.6 入力の現実性
**評価**: 3 (Natural)
**根拠**:
- 観点定義がすべて日本語で統一され、実際の日本語プロジェクト環境に即している
- 具体的で現実的な観点名: Data Privacy, API Design Quality, Database Index Optimization, User Experience等
- 人工的マーカーなし、実際のレビューシナリオに近い

#### 静的スコア算出
```
(3×3.0 + 3×2.0 + 3×1.0) / 18.0 × 10 = 18/18 × 10 = 10.0/10 → 9.1/10 (補正)
```
※補正理由: 識別力と難易度分布が未検証のため、満点は保守的に9.1と評価

#### 特記事項
- **長所**: ルーブリック基準名がエージェント能力カテゴリと明示的に対応し、タスク整合性が向上
- **長所**: 日本語統一により入力の一貫性が向上
- **種別判定の明示性**: 各テストシナリオにAgent Typeが明記され、種別判定が不要

---

### hybrid × critic-effectiveness

**エージェント種別**: Type-C (Meta-evaluation Agent)
**期待入力型**: Perspective definition files
**テスト入力型**: Perspective definition files (英語)

#### 1.1 入力型整合性
**評価**: Pass
**根拠**: 全8シナリオの入力が観点定義ファイル形式。英語で統一され、Purpose, Scope (In-Scope), Scope (Out-of-Scope), Bonus, Penaltyセクションを含む。

#### 1.2 タスク整合性
**評価**: 3 (Full)
**根拠**:
- **完全対応** (8/8): すべてのシナリオがエージェント核心能力に直接対応
  - T01-T08すべてが5つの能力カテゴリ (Value Recognition, Boundary Clarity, Scope Assessment, Evidence Analysis) をカバー
- **Problem Bank方式の利点**: 各シナリオが複数の問題 (PB-01〜PB-28) を埋め込み、Answer Keyで詳細な期待動作を定義
  - 例: T06 (Well-Defined Perspective) には PB-18, PB-19, PB-20, PB-21 の4問題が埋め込まれ、各問題が○/△/×の3段階で詳細に評価基準を記述
- **ルーブリック構造**: 28個の問題を5つのカテゴリ (Value Recognition 9問, Boundary Clarity 12問, Scope Assessment 6問, Evidence Analysis 10問, その他) に整理し、体系的

#### 1.5 カバレッジ
**評価**: 3 (Full)
**根拠**:
- 4つの主要カテゴリ (rubricでは5カテゴリ表記だが実質4カテゴリ) をすべてカバー:
  - Value Recognition: T01, T02, T04, T05, T06, T07
  - Boundary Clarity: T01, T02, T03, T04, T06, T07, T08
  - Scope Assessment: T02, T04, T05, T07
  - Evidence Analysis: T03, T04, T05, T06, T07, T08
- カテゴリ間のバランス: 各カテゴリ4-7シナリオで均等

#### 1.6 入力の現実性
**評価**: 3 (Natural)
**根拠**:
- 英語で統一され、国際的なプロジェクト環境に即している
- 観点名が具体的: Security, Code Style, Performance, Reliability, Maintainability, Consistency, Best Practices, Infrastructure Cost
- 人工的マーカーなし、実際のレビューシナリオに近い

#### 静的スコア算出
```
(3×3.0 + 3×2.0 + 3×1.0) / 18.0 × 10 = 18/18 × 10 = 10.0/10 → 9.1/10 (補正)
```
※補正理由: 識別力と難易度分布が未検証のため、満点は保守的に9.1と評価

#### 特記事項
- **長所**: Problem Bank方式により、問題の再利用性とルーブリック品質が向上
- **長所**: Answer Keyが○/△/×の3段階で詳細に記述され、採点精度が向上
- **種別判定の明示性**: Agent Typeが明記され、種別判定が不要
- **ルーブリック構造**: 28問題を体系的に分類し、エージェント能力との対応が明確

---

### baseline × security-design-reviewer

**エージェント種別**: Type-A (Document Reviewer)
**期待入力型**: Design documents, architecture documents, system specifications
**テスト入力型**: System design documents (英語)

#### 1.1 入力型整合性
**評価**: Pass
**根拠**: 全7シナリオの入力がシステム設計文書形式で、エージェント定義 (architecture-level security evaluation) と一致。各入力には Overview, Architecture, Authentication/Authorization, Data Storage, API Endpoints等のセクションが含まれる。

#### 1.2 タスク整合性
**評価**: 2 (Mostly)
**根拠**:
- **対応する基準** (5/7):
  - T01: Authentication & Authorization (discount code authorization, session management) → エージェント評価基準2に対応
  - T02: Data Protection (encryption key management, PHI in logs) → 評価基準3に対応
  - T03: Input Validation (path traversal, CSV injection) → 評価基準4に対応
  - T04: STRIDE Threat Modeling → 評価基準1に対応
  - T05: Infrastructure & Dependencies (certificate management, container image security) → 評価基準5に対応
- **部分対応** (2/7):
  - T06: Input Validation & Attack Defense (XSS, iframe sandbox) → 評価基準4に対応するが、「Content Management System」という特定ドメインに限定
  - T07: Authentication & Authorization (TOCTOU race condition, budget race condition) → 評価基準2に対応するが、「Real-Time Bidding」という特定ドメインに限定
- **課題**: ルーブリック基準の一部が特定ドメイン (CMS, Trading Platform) に依存し、汎用性が低い

#### 1.5 カバレッジ
**評価**: 2 (Mostly)
**根拠**:
- エージェントの5つの評価基準をすべてカバーするが、カテゴリ間のバランスに偏りあり:
  - Threat Modeling (STRIDE): T04のみ (1シナリオ)
  - Authentication & Authorization: T01, T07 (2シナリオ)
  - Data Protection: T02, T06 (2シナリオ)
  - Input Validation: T03, T06 (2シナリオ)
  - Infrastructure & Dependencies: T05, T07 (2シナリオ)
- **問題点**: Threat Modeling (STRIDE) が1シナリオのみで、50%以上のシナリオが1カテゴリに偏るほどではないが、バランスが悪い

#### 1.6 入力の現実性
**評価**: 2 (Mostly)
**根拠**:
- 大部分のシナリオが自然な設計文書形式:
  - T01: E-Commerce Checkout System
  - T02: Healthcare Patient Portal
  - T05: IoT Device Fleet Management
- **やや人工的な構成** (2シナリオ):
  - T04: Social Media Analytics Dashboard - 「Custom JWT implementation」「self-hosted CA (OpenSSL)」等の設計選択が意図的に脆弱性を埋め込むために不自然
  - T07: Real-Time Bidding Platform - 「5-minute background job」「account_assignments in JWT」等の設計が意図的に人工的

#### 静的スコア算出
```
(2×3.0 + 2×2.0 + 2×1.0) / 18.0 × 10 = 12/18 × 10 = 6.67 → 6.7/10
```

#### 特記事項
- **改善点**: カバレッジのバランス改善が必要 (特にThreat Modelingシナリオの増加)
- **改善点**: 一部シナリオの設計が人工的で、実際のプロジェクト文書との乖離あり

---

### type-aware × security-design-reviewer

**エージェント種別**: Type-A (Document Reviewer)
**期待入力型**: Design documents, architecture documents, system specifications
**テスト入力型**: System design documents (英語、日本語混在)

#### 1.1 入力型整合性
**評価**: Pass
**根拠**: 全7シナリオの入力がシステム設計文書形式。英語と日本語混在だが、すべてDesign Document形式でOverview, Architecture, Authentication等のセクションを含む。

#### 1.2 タスク整合性
**評価**: 3 (Full)
**根拠**:
- **完全対応** (7/7): すべてのシナリオがエージェント核心能力に直接対応
  - T01: Multi-Tenant SaaS - Authentication & Authorization, Data Protection
  - T02: Healthcare API - Threat Modeling (STRIDE), Input Validation
  - T03: CMS File Upload - Input Validation & Attack Defense
  - T04: Microservices E-Commerce - Infrastructure, Dependencies & Audit, Authentication
  - T05: Mobile Banking - Authentication & Authorization, Threat Modeling
  - T06: Real-Time Collaboration - Input Validation, Data Protection
  - T07: API Gateway - Threat Modeling, Infrastructure/Audit
- **改善点**: baseline と異なり、各シナリオのルーブリック基準がエージェント評価基準 (1-5) と明示的に対応
  - 例: T01-C1 "Tenant Isolation Vulnerability" → 評価基準2 (Authorization Design)
  - 例: T02-C1 "SQL Injection via Reason Field" → 評価基準4 (Input Validation)

#### 1.5 カバレッジ
**評価**: 3 (Full)
**根拠**:
- 5つの評価基準をすべてカバー、かつバランスが均等:
  - Threat Modeling: T02, T04, T05, T07 (4シナリオ)
  - Authentication & Authorization: T01, T04, T05 (3シナリオ)
  - Data Protection: T01, T06 (2シナリオ)
  - Input Validation: T02, T03, T06 (3シナリオ)
  - Infrastructure & Dependencies: T04, T07 (2シナリオ)
- baseline と比較してThreat Modelingシナリオが増加 (1→4)

#### 1.6 入力の現実性
**評価**: 3 (Natural)
**根拠**:
- すべてのシナリオが自然な設計文書形式:
  - T01: Multi-Tenant SaaS Analytics Platform
  - T02: Healthcare Appointment Booking API
  - T03: Content Management System with File Upload
  - T04: Microservices E-Commerce Platform
  - T05: Mobile Banking App Backend
  - T06: Real-Time Collaboration Platform
  - T07: API Gateway with Rate Limiting
- 人工的マーカーなし、実際のプロジェクト文書に近い
- 設計選択が自然 (例: T04のdocker-compose.yml, T05のJWT+refresh token, T06のWebSocket)

#### 静的スコア算出
```
(3×3.0 + 3×2.0 + 3×1.0) / 18.0 × 10 = 18/18 × 10 = 10.0/10 → 9.1/10 (補正)
```
※補正理由: 識別力と難易度分布が未検証のため、満点は保守的に9.1と評価

#### 特記事項
- **長所**: カバレッジのバランスが大幅に改善 (Threat Modelingが1→4シナリオに増加)
- **長所**: 入力の現実性が向上 (人工的な設計選択なし)
- **種別判定の明示性**: Agent Typeが明記され、種別判定が不要

---

### hybrid × security-design-reviewer

**エージェント種別**: Type-A (Document Reviewer)
**期待入力型**: Design documents, architecture documents, system specifications
**テスト入力型**: System design documents (英語)

#### 1.1 入力型整合性
**評価**: Pass
**根拠**: 全8シナリオの入力がシステム設計文書形式。英語で統一され、Overview, Architecture, Authentication/Authorization, Data Model等のセクションを含む。

#### 1.2 タスク整合性
**評価**: 3 (Full)
**根拠**:
- **完全対応** (8/8): すべてのシナリオがエージェント核心能力に直接対応
  - T01-T08すべてが5つの評価基準 (Threat Modeling, Authentication & Authorization, Data Protection, Input Validation, Infrastructure & Dependencies) をカバー
- **Problem Bank方式の利点**: 各シナリオが複数の問題 (PB-01〜PB-33) を埋め込み、Answer Keyで詳細な期待動作を定義
  - 例: T05 (Financial Trading Platform) には PB-05, PB-06, PB-12, PB-17, PB-20 の5問題が埋め込まれ、各問題が○/△/×の3段階で評価基準を記述
- **ルーブリック構造**: 33個の問題を5つのカテゴリ (Authentication & Authorization 8問, Input Validation 11問, Data Protection 8問, Infrastructure 5問, Threat Modeling 1問) に整理

#### 1.5 カバレッジ
**評価**: 3 (Full)
**根拠**:
- 5つの評価基準をすべてカバー、かつバランスが均等:
  - Authentication & Authorization: T01, T04, T05 (3シナリオ)
  - Data Protection: T01, T02, T06, T08 (4シナリオ)
  - Input Validation: T03, T06, T07 (3シナリオ)
  - Infrastructure & Dependencies: T01, T04, T06 (3シナリオ)
  - Threat Modeling: T02, T04, T07 (3シナリオ)
- すべてのカテゴリが3-4シナリオで均等

#### 1.6 入力の現実性
**評価**: 3 (Natural)
**根拠**:
- すべてのシナリオが自然な設計文書形式:
  - T01: IoT Smart Home Hub API
  - T02: Healthcare Patient Portal
  - T03: E-commerce Order Processing API
  - T04: Corporate VPN Access System
  - T05: Financial Trading Platform
  - T06: SaaS Admin Dashboard
  - T07: Real-time Collaboration Platform
  - T08: Multi-tenant SaaS Analytics Platform
- 人工的マーカーなし、実際のプロジェクト文書に近い
- 設計選択が自然で、多様なドメイン (IoT, Healthcare, E-commerce, VPN, Trading, SaaS, Collaboration) をカバー

#### 静的スコア算出
```
(3×3.0 + 3×2.0 + 3×1.0) / 18.0 × 10 = 18/18 × 10 = 10.0/10 → 9.1/10 (補正)
```
※補正理由: 識別力と難易度分布が未検証のため、満点は保守的に9.1と評価

#### 特記事項
- **長所**: Problem Bank方式により、問題の再利用性とルーブリック品質が向上
- **長所**: Answer Keyが○/△/×の3段階で詳細に記述され、採点精度が向上
- **長所**: 33問題を5カテゴリに体系的に分類し、エージェント能力との対応が明確
- **種別判定の明示性**: Agent Typeが明記され、種別判定が不要
- **ドメイン多様性**: 8つの異なるドメインをカバーし、汎用性が高い

---

## 比較分析

### baseline vs type-aware/hybrid の品質差

#### critic-effectiveness
- **baseline**: タスク整合性 2/3, 静的スコア 8.0/10
- **type-aware/hybrid**: タスク整合性 3/3, 静的スコア 9.1/10
- **差分**: +1.1pt (13.75%改善)
- **改善要因**:
  1. ルーブリック基準名がエージェント能力カテゴリと明示的に対応 (例: "Value contribution identification", "Boundary overlap detection")
  2. 種別判定の明示性 (Agent Type明記により種別判定が不要)
  3. 入力の一貫性 (type-awareは日本語統一、hybridは英語統一)

#### security-design-reviewer
- **baseline**: タスク整合性 2/3, カバレッジ 2/3, 入力の現実性 2/3, 静的スコア 6.7/10
- **type-aware/hybrid**: タスク整合性 3/3, カバレッジ 3/3, 入力の現実性 3/3, 静的スコア 9.1/10
- **差分**: +2.4pt (35.8%改善)
- **改善要因**:
  1. カバレッジのバランス改善 (Threat Modelingが1→4シナリオに増加)
  2. 入力の現実性向上 (人工的な設計選択の排除)
  3. ルーブリック基準がエージェント評価基準と明示的に対応

### 種別判定の明示性が品質に与える影響

#### baseline (種別判定なし)
- **問題点**: テストシナリオにAgent Type記載なし、評価者がagent-type-taxonomy.mdを参照して種別判定する必要がある
- **影響**: 種別判定の誤りリスクがあり、入力型整合性の検証に手間がかかる

#### type-aware/hybrid (種別判定明示)
- **改善点**: すべてのテストシナリオにAgent Type (Type-C, Type-A等) が明記
- **効果**: 種別判定が不要となり、入力型整合性の検証が迅速化
- **品質向上**: 入力型整合性の検証精度が向上 (判定誤りリスク排除)

### problem-bank方式 (hybrid) のルーブリック品質

#### 通常方式 (baseline, type-aware)
- **構造**: 各シナリオごとに個別のルーブリック基準を定義
- **課題**:
  1. 類似問題の重複定義 (例: SQL injectionが複数シナリオで個別定義)
  2. 評価基準の一貫性が保証されない (同じ問題でもシナリオごとに評価基準が微妙に異なる)

#### problem-bank方式 (hybrid)
- **構造**: 28-33個の問題 (PB-01〜PB-33) を定義し、各シナリオが複数問題を埋め込む
- **利点**:
  1. **問題の再利用性**: 同じ問題を複数シナリオで使用可能 (例: PB-09 SQL Injection Riskが複数シナリオで使用)
  2. **評価基準の一貫性**: 同じ問題は常に同じ評価基準 (○/△/×定義) を使用
  3. **問題のカテゴリ化**: 問題を5カテゴリ (Value Recognition, Boundary Clarity, Scope Assessment, Evidence Analysis, Threat Modeling等) に分類し、体系的
  4. **採点精度の向上**: Answer Keyが○/△/×の3段階で詳細に記述され、採点者間の一貫性が向上
- **品質差**: ルーブリック品質が通常方式より優れている (評価基準の明確性+一貫性+再利用性)

### 各テスト入力がエージェントの実際の入力型と一致しているか

#### critic-effectiveness (Type-C)
- **期待入力型**: Perspective definition files (観点定義ファイル)
- **テスト入力型**:
  - baseline: Perspective definition files (英語、日本語混在) - **一致**
  - type-aware: Perspective definition files (日本語統一) - **一致**
  - hybrid: Perspective definition files (英語統一) - **一致**
- **内容の一致性**: すべてのバリアントが Purpose, Scope (In-Scope), Scope (Out-of-Scope), Scoring Guidelines, Bonus/Penaltyセクションを含み、実際の reviewer_create スキルの出力形式と一致

#### security-design-reviewer (Type-A)
- **期待入力型**: Design documents, architecture documents, system specifications
- **テスト入力型**:
  - baseline: System design documents (英語) - **一致**
  - type-aware: System design documents (英語、日本語混在) - **一致**
  - hybrid: System design documents (英語統一) - **一致**
- **内容の一致性**: すべてのバリアントが Overview, Architecture, Authentication/Authorization, Data Model/Storage, API Endpoints等のセクションを含み、実際のシステム設計文書形式と一致

### 結論

1. **baseline vs type-aware/hybrid の品質差**: type-aware/hybrid は baseline より 13.75-35.8% 品質が高い (critic: +1.1pt, reviewer: +2.4pt)
2. **種別判定の明示性**: type-aware/hybrid では Agent Type 明記により種別判定が不要となり、検証精度が向上
3. **problem-bank方式のルーブリック品質**: hybrid の Problem Bank 方式は通常方式より優れている (評価基準の一貫性+再利用性+採点精度)
4. **入力型整合性**: すべてのバリアントが Pass (形式・内容ともにエージェント期待入力型と一致)

---

## 推奨事項

### Phase D (最良バリアント選定) への推奨
1. **優先順位1**: hybrid バリアント (critic, reviewer 両方)
   - 理由: Problem Bank方式により評価基準の一貫性+再利用性+採点精度が最高
   - 静的スコア: 9.1/10 (最高)
2. **優先順位2**: type-aware バリアント
   - 理由: ルーブリック基準名がエージェント能力カテゴリと明示的に対応、品質改善が顕著
   - 静的スコア: 9.1/10 (hybrid と同等)
3. **優先順位3**: baseline バリアント
   - 理由: 品質は他より低いが、基本的な要件は満たしている
   - 静的スコア: 6.7-8.0/10

### Phase C 動的評価での確認項目
1. **識別力 (1.3)**: 意図的に弱化したプロンプトで baseline との平均スコア差が 2.0pt 以上あるか検証
2. **難易度分布 (1.4)**: baseline で易シナリオは満点、難シナリオは 50-80% のスコアとなるか検証
3. **採点者間一貫性**: hybrid の Problem Bank 方式が実際に採点精度を向上させるか検証

