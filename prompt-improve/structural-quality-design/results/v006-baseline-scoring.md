# Scoring Report: v006-baseline

## Embedded Problems Detection Matrix

| Problem ID | Description | Run1 | Run2 | Notes |
|------------|-------------|------|------|-------|
| P01 | BuildingServiceの単一責務原則違反 | ○ | ○ | Run1: C-1で明確に検出（SRP違反、複数責務の列挙）。Run2: Issue 1で明確に検出（SRP違反、5つの責務を列挙） |
| P02 | Application LayerからInfrastructure Layerへの直接依存 | ○ | ○ | Run1: C-2で明確に検出（DIP違反、インターフェース不足を指摘）。Run2: Issue 2で明確に検出（DIP違反、abstraction interfaces不足） |
| P03 | SensorDataテーブルの複合主キー設計の冗長性リスク | × | × | 両方未検出。データモデル設計に関する指摘はあるが、複合主キーの冗長性やEAVパターンの欠点には言及なし |
| P04 | エラーハンドリング戦略におけるリトライ可能/不可能エラーの区別不足 | ○ | ○ | Run1: C-5で明確に検出（リトライ可能/不可能エラーの区別不足）。Run2: Issue 3で明確に検出（retryable vs non-retryable errors） |
| P05 | API設計における動詞ベースURLとHTTPメソッド不一致 | × | × | 両方未検出。API設計に関する指摘はあるが、`/control`エンドポイントのRESTful原則違反には具体的に言及なし |
| P06 | APIバージョニング戦略の欠如 | ○ | ○ | Run1: C-4で明確に検出（後方互換性リスク、バージョニング戦略不足）。Run2: Issue 8で明確に検出（backward compatibility、deprecation policy） |
| P07 | テスト戦略における統合テスト境界の曖昧さ | △ | △ | Run1: M-4「Lack of Testability Design for Kafka Consumers」は単体/統合テストの境界を部分的に示唆。Run2: Issue 11「Missing Test Data Management Strategy」はテスト戦略の改善を指摘しているが、単体/統合テストの境界の観点からの具体的指摘ではない |
| P08 | 環境固有設定の管理戦略不足 | ○ | ○ | Run1: M-1で明確に検出（環境別設定の差分管理、検証戦略不足）。Run2: Issue 12で明確に検出（environment-specific settings、secrets management） |
| P09 | JWT保存先の未定義とセキュリティリスク | × | × | 両方未検出。JWT認証に関する記述が設計書にあるが、保存先の未定義やセキュリティリスクには言及なし |

## Detection Score Breakdown

| Run | Detection Score Calculation |
|-----|---------------------------|
| Run1 | P01(1.0) + P02(1.0) + P03(0.0) + P04(1.0) + P05(0.0) + P06(1.0) + P07(0.5) + P08(1.0) + P09(0.0) = 5.5 |
| Run2 | P01(1.0) + P02(1.0) + P03(0.0) + P04(1.0) + P05(0.0) + P06(1.0) + P07(0.5) + P08(1.0) + P09(0.0) = 5.5 |

## Bonus Points Analysis

### Run1 Bonuses

| ID | Category | Description | Bonus |
|----|----------|-------------|-------|
| B01 | SOLID原則 | C-3: Circular Dependency Risk Between Application and Domain Layers（JPA依存によるレイヤー境界侵害） | +0.5 |
| B02 | SOLID原則 | S-4: AlertManager Responsibility Overload（AlertManagerのSRP違反、責務分離提案） | +0.5 |
| B03 | 変更容易性 | S-2: DTO vs. Entity Separation Not Enforced（DTO/Entity分離不足） | +0.5 |
| B04 | 拡張性 | S-3: No Strategy for Handling Schema Evolution in TimescaleDB（スキーマ進化戦略不足） | +0.5 |
| B05 | エラーハンドリング | M-2: No Tracing Design for Distributed System（分散トレーシング戦略不足） | +0.5 |
| **Total** | | | **+2.5** |

### Run2 Bonuses

| ID | Category | Description | Bonus |
|----|----------|-------------|-------|
| B01 | SOLID原則 | Issue 4: Circular Dependency Risk Between Services（サービス間循環依存リスク） | +0.5 |
| B02 | 変更容易性 | Issue 5: Missing DTO/Entity Separation（DTO/Entity分離不足） | +0.5 |
| B03 | 拡張性 | Issue 6: No Strategy for Long-Running Operations（非同期実行戦略不足） | +0.5 |
| B04 | 変更容易性 | Issue 7: Inadequate State Management Design for Device Control（デバイス制御の状態管理不足） | +0.5 |
| B05 | エラーハンドリング | Issue 10: Insufficient Logging Design for Distributed Tracing（分散トレーシング設計不足） | +0.5 |
| **Total** | | | **+2.5** |

## Penalty Points Analysis

### Run1 Penalties

No penalties. All issues are within the structural-quality scope.

**Total Penalties: 0**

### Run2 Penalties

No penalties. All issues are within the structural-quality scope.

**Total Penalties: 0**

## Final Scores

| Run | Detection | Bonus | Penalty | Total |
|-----|-----------|-------|---------|-------|
| Run1 | 5.5 | +2.5 | -0.0 | **8.0** |
| Run2 | 5.5 | +2.5 | -0.0 | **8.0** |

## Statistical Summary

- **Mean Score**: 8.0
- **Standard Deviation**: 0.0
- **Stability**: 高安定（SD = 0.0）

## Detection Analysis

### Successfully Detected (5/9 = 55.6%)

1. **P01 (BuildingServiceのSRP違反)**: 両方のRunで明確に検出。最も重大な構造的問題として最初に指摘されている
2. **P02 (DIP違反)**: 両方のRunで明確に検出。外部API依存の抽象化不足を指摘
3. **P04 (リトライ可能/不可能エラーの区別不足)**: 両方のRunで明確に検出。エラー分類体系の必要性を指摘
4. **P06 (APIバージョニング戦略の欠如)**: 両方のRunで明確に検出。後方互換性リスクを指摘
5. **P08 (環境固有設定の管理戦略不足)**: 両方のRunで明確に検出。環境差分管理と検証戦略の不足を指摘

### Partially Detected (1/9 = 11.1%)

1. **P07 (テスト戦略における統合テスト境界の曖昧さ)**: 両方のRunで部分検出(△)。テスト戦略の改善を指摘しているが、単体/統合テストの境界の観点からの具体的指摘には至っていない

### Missed (3/9 = 33.3%)

1. **P03 (SensorDataテーブルの複合主キー設計の冗長性リスク)**: 両方のRunで未検出。データモデル設計に関する指摘はあるが、複合主キーの冗長性やEAVパターンの欠点には言及なし
2. **P05 (API設計における動詞ベースURLとHTTPメソッド不一致)**: 両方のRunで未検出。API設計に関する指摘はあるが、`/control`エンドポイントのRESTful原則違反には具体的に言及なし
3. **P09 (JWT保存先の未定義とセキュリティリスク)**: 両方のRunで未検出。JWT認証に関する記述が設計書にあるが、保存先の未定義やセキュリティリスクには言及なし（security観点でスコープ外と判断された可能性）

### Detection Pattern

- **SOLID原則・構造設計**: 2/2検出（P01, P02）
- **API・データモデル品質**: 1/3検出（P06のみ。P03, P05は未検出）
- **エラーハンドリング・オブザーバビリティ**: 1/1検出（P04）
- **拡張性・運用設計**: 1/1検出（P08）
- **テスト設計・テスタビリティ**: 0.5/1検出（P07は部分検出）
- **変更容易性・モジュール設計**: 0/1検出（P09は未検出。ただしsecurity観点でスコープ外の可能性）

### Stability Analysis

標準偏差0.0は完全に安定しており、同じプロンプトで再実行しても同じスコアが得られることを示す。これは：

1. 検出ロジックが一貫している
2. 両方のRunで同じ問題を同じように認識している
3. ボーナス/ペナルティの判断基準が明確

ただし、P03, P05, P09の検出漏れも一貫しており、プロンプトがこれらの問題を検出できない構造的限界がある可能性を示唆している。

## Recommendations for Improvement

1. **データモデル設計の深掘り**: P03（複合主キー設計の冗長性）を検出するには、データモデルの正規化・非正規化トレードオフ、EAVパターンの特性、時系列DBの設計パターンに関する知識が必要。正解キーの説明を参考に、「複合主キーによるデータ冗長性」「メトリック横断集計時のクエリ複雑化」等のキーワードを含めた検出ロジックの強化を検討

2. **RESTful API設計原則の強化**: P05（動詞ベースURLとHTTPメソッド不一致）を検出するには、RESTful設計原則（リソース指向、HTTPメソッドのセマンティクス）の理解を深める必要がある。`PUT`が「リソース全体の置換」を意味する一方、`/control`が「アクション実行」を意味することの矛盾を指摘できるよう、API設計レビューの観点を追加

3. **認証状態管理の明示化**: P09（JWT保存先の未定義とセキュリティリスク）を検出するには、フロントエンド/モバイルアプリの認証状態管理戦略を評価対象に含める必要がある。ただし、これはsecurity観点と重複する可能性があるため、structural-quality観点では「状態管理」の側面に焦点を当てる

4. **テスト戦略の境界定義**: P07（テスト戦略における統合テスト境界の曖昧さ）は部分検出に留まっている。「単体テストと統合テストの役割分担」「テストレイヤーの責務」等の具体的なキーワードを含めた検出ロジックの強化を検討
