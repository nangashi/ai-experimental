# Scoring Results: v005-baseline

## Detection Matrix

| Problem ID | Description | Run1 | Run2 |
|-----------|-------------|------|------|
| P01 | PropertyManagementServiceの単一責務原則違反 | ○ | ○ |
| P02 | NotificationServiceの外部依存直接結合 | ○ | ○ |
| P03 | データモデルの冗長性とデータ整合性リスク | ○ | ○ |
| P04 | PropertyManagementServiceの過剰な依存注入 | ○ | ○ |
| P05 | RESTful API設計原則違反（動詞ベースURL） | ○ | ○ |
| P06 | エラー分類・リカバリー戦略の欠如 | ○ | ○ |
| P07 | 環境固有設定の管理戦略欠如 | ○ | ○ |
| P08 | テスト戦略の具体性不足 | △ | △ |
| P09 | Cookieベースのトークン保存によるセキュリティリスク | × | × |

### Detection Details

#### P01: PropertyManagementServiceの単一責務原則違反
- **Run1**: ○ (検出) - Issue #1で「PropertyManagementServiceが複数の責務（物件管理、マッチング、予約、契約、統計）を持つ」ことを明確に指摘し、単一責務原則違反とgod class anti-patternとして言及
- **Run2**: ○ (検出) - C-1で「PropertyManagementServiceが5つの異なる責務を統合している」ことを指摘し、SRP違反を明確に言及

#### P02: NotificationServiceの外部依存直接結合
- **Run1**: ○ (検出) - Issue #2で「NotificationServiceがSMTP/SMS APIキーをハードコード」していることを指摘し、Dependency Inversion Principle違反とtestability問題を明確に言及
- **Run2**: ○ (検出) - C-4で「NotificationServiceがハードコードされた認証情報を持つ」ことを指摘し、テスタビリティとDIP違反を言及

#### P03: データモデルの冗長性とデータ整合性リスク
- **Run1**: ○ (検出) - Issue #11で「propertiesテーブルにオーナー情報が埋め込まれている」ことを指摘し、データ冗長性とdenormalization without strategyとして問題提起。また、外部キー制約の欠如については明示的に言及していないが、#4でschema versioningの文脈で「データ整合性」について触れている
- **Run2**: ○ (検出) - C-2で「propertiesテーブルがオーナー情報を直接埋め込み」と「外部キー制約が定義されていない」の両方を明確に指摘し、データ冗長性と整合性リスクを詳述

#### P04: PropertyManagementServiceの過剰な依存注入
- **Run1**: ○ (検出) - Issue #1で「6つの依存（repositories/templates）がAutowiredされている」ことを指摘し、SRP違反の兆候として言及
- **Run2**: ○ (検出) - C-1で「6つの注入されたrepositories/templates」について言及し、過剰な依存の問題として指摘

#### P05: RESTful API設計原則違反（動詞ベースURL）
- **Run1**: ○ (検出) - Issue #10で「/properties/create, /properties/update/{id}, /properties/delete/{id}」という動詞ベースURLを指摘し、「violates REST conventions」として明確に言及
- **Run2**: ○ (検出) - M-3で「POST /properties/create, PUT /properties/update/{id}」などの動詞ベースURLを指摘し、RESTful原則違反として明確に言及

#### P06: エラー分類・リカバリー戦略の欠如
- **Run1**: ○ (検出) - Issue #6で「エラーハンドリングがHTTPステータスコードのみで、アプリケーションレベルのエラー分類・リトライ可能/不可能の区別が欠如」していることを指摘
- **Run2**: ○ (検出) - S-2で「エラー分類体系の欠如、retryable/non-retryableエラーの区別がない」ことを明確に指摘

#### P07: 環境固有設定の管理戦略欠如
- **Run1**: ○ (検出) - Issue #13で「複数環境（dev/staging/prod）が存在するが、環境固有設定の管理方法が明示されていない」ことを指摘
- **Run2**: ○ (検出) - M-2で「staging/production環境が言及されているが、環境間の設定差分管理戦略が定義されていない」ことを指摘

#### P08: テスト戦略の具体性不足
- **Run1**: △ (部分検出) - Issue #17で「テスト戦略が各コンポーネントのテストタイプを定義していない」と指摘しているが、外部依存のモック/スタブ方針については言及がない
- **Run2**: △ (部分検出) - M-1で「テスト戦略に関する指摘があるが、各層の役割分担の曖昧さについては触れているものの、外部依存のテスト方針については直接的な言及がない」

#### P09: Cookieベースのトークン保存によるセキュリティリスク
- **Run1**: × (未検出) - JWT/Cookieに関する言及はあるが（Issue #16で「Cookie based token storage may limit mobile app extensibility」）、これはセキュリティリスクではなく拡張性の観点からの指摘であり、CSRF対策との整合性やセキュリティ属性（SameSite, HttpOnly）の欠如については言及なし
- **Run2**: × (未検出) - I-2で「JWTのCookie保存がモバイルアプリ拡張性を制限する」と指摘しているが、これは拡張性の問題であり、CSRFリスクやセキュリティ属性の欠如については言及なし

## Bonus/Penalty Analysis

### Run1 Bonuses

1. **Schema versioning/migration strategy欠如** (B-domain; +0.5) - Issue #4で「schema evolution, data migration, backward compatibility戦略が欠如」を指摘。これは拡張性・運用設計の観点で有益な追加指摘
2. **Repository layer abstraction欠如** (B-design; +0.5) - Issue #5で「Spring Data JPAを直接露出し抽象化レイヤーがない」ことを指摘。変更容易性の観点で有益
3. **Layer separation欠如とcircular dependency risk** (B-design; +0.5) - Issue #7で「3層アーキテクチャを主張しながらパッケージ構造やモジュール境界が示されていない、循環依存のリスク」を指摘。SOLID原則・構造設計の観点で有益
4. **State management/transaction boundary設計欠如** (B-design; +0.5) - Issue #8で「トランザクション境界、一貫性要件、複数データストア間の整合性戦略が明示されていない」ことを指摘。変更容易性・状態管理の観点で有益
5. **No idempotency strategy** (B-design; +0.5) - Issue #16で「property作成やcontract更新などの重要操作に対するidempotency keysや重複リクエスト検出がない」ことを指摘。API品質の観点で有益

**Bonuses: 5件 (+2.5点)**

### Run1 Penalties

なし

**Penalties: 0件 (-0点)**

---

### Run2 Bonuses

1. **Domain model layer欠如** (B-design; +0.5) - S-1で「DTOがドメインオブジェクトとして直接使用され、独立したドメインモデル層が欠如」を指摘。変更容易性・モジュール設計の観点で有益（B05に相当）
2. **Circular dependency risk in matching logic** (B-design; +0.5) - S-3で「PropertyManagementServiceとCustomerMatching間の循環依存リスク」を指摘。SOLID原則・構造設計の観点で有益
3. **Schema evolution strategy欠如** (B-design; +0.5) - S-4で「schema変更管理、migration戦略、backward compatibility handling、data type changesの指針が欠如」を指摘。拡張性・運用設計の観点で有益
4. **DI設計の不足** (B-testability; +0.5) - M-1で「field injectionの使用、外部依存の抽象化レイヤー欠如、constructor injectionの必要性」を指摘。テスト設計・テスタビリティの観点で有益（B06に相当）
5. **No distributed tracing design** (B-observability; +0.5) - M-4で「distributed tracing設計欠如、コンテキスト伝播、trace spans定義の欠如」を指摘。エラーハンドリング・オブザーバビリティの観点で有益（B04に相当）

**Bonuses: 5件 (+2.5点)**

### Run2 Penalties

なし

**Penalties: 0件 (-0点)**

---

## Score Calculation

### Run1
- 検出スコア: P01(1.0) + P02(1.0) + P03(1.0) + P04(1.0) + P05(1.0) + P06(1.0) + P07(1.0) + P08(0.5) + P09(0.0) = **8.5**
- ボーナス: +2.5
- ペナルティ: -0.0
- **Total: 11.0**

### Run2
- 検出スコア: P01(1.0) + P02(1.0) + P03(1.0) + P04(1.0) + P05(1.0) + P06(1.0) + P07(1.0) + P08(0.5) + P09(0.0) = **8.5**
- ボーナス: +2.5
- ペナルティ: -0.0
- **Total: 11.0**

### Overall Statistics
- **Mean**: (11.0 + 11.0) / 2 = **11.0**
- **Standard Deviation**: 0.0
- **Stability**: 高安定 (SD = 0.0 ≤ 0.5)

---

## Analysis Summary

### Strengths
- 両方のRunで9問中8問（P01-P07を完全検出、P08を部分検出）を一貫して検出
- ボーナス検出も両Runで5件ずつと安定
- 特にP01-P07の重大〜中程度の問題を全て完全検出し、検出精度が非常に高い
- ペナルティなしで、スコープ逸脱がない高品質な指摘

### Weaknesses
- **P09（Cookieベースのトークン保存によるセキュリティリスク）が両Runで未検出**
  - 両Runともモバイルアプリ拡張性の観点からの指摘はあるが、CSRF対策との整合性やSameSite/HttpOnly属性の欠如といったセキュリティ観点での指摘がない
  - P09は「変更容易性・モジュール設計（状態管理）」カテゴリに分類されているが、実際にはセキュリティ要素が強く、structural-qualityのスコープ境界が曖昧
- **P08（テスト戦略の具体性不足）が両Runで部分検出**
  - テスト戦略の改善提案はあるが、「各層の役割分担の曖昧さ」と「外部依存のテスト方針」の両方を明確に指摘するには至っていない

### Consistency
- 完全に一貫した検出パターン（検出マトリクスが両Runで同一）
- ボーナス検出数も同じ（5件ずつ）
- SD = 0.0の完全安定性

### Recommendations
- P09の検出を改善するには、「状態管理」カテゴリにおいてセキュリティ関連の状態（トークン保存方式、セッション管理等）の評価観点を強化する必要がある
- P08の完全検出には、テスト戦略評価時に「役割分担」と「外部依存テスト方針」の両方を明示的にチェックリストに含める必要がある
