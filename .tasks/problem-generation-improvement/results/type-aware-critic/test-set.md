# Test Scenario Set: critic-effectiveness (Type-C Meta Evaluation Agent)

**Agent Name**: critic-effectiveness
**Agent Type**: Type-C (Meta evaluation agent)
**Input Type**: Perspective definition files
**Total Scenarios**: 7
**Capability Categories**: Boundary verification, Value contribution, Cross-reference accuracy, Scope appropriateness, Actionability

---

### T01: Clear Value Proposition with Minor Boundary Ambiguity

**Difficulty**: Easy
**Category**: Value contribution + Boundary verification

#### Input

Perspective definition file to evaluate:

```markdown
# Perspective: Data Privacy

## Purpose
評価対象の設計書において、個人情報保護とデータプライバシー要件が適切に考慮されているかを評価します。

## Evaluation Scope
このパースペクティブでは以下を評価します:
1. 個人情報の収集・保存・削除ポリシーの明確性
2. GDPRやPIPEDA等の規制準拠の考慮
3. データアクセス制御とアクセスログの設計
4. ユーザー同意取得とオプトアウト機構
5. データ匿名化・仮名化の戦略

## Out of Scope
以下は本パースペクティブの範囲外です:
- 認証・認可メカニズムの技術的実装 → Security観点
- データベース暗号化の技術的詳細 → Security観点
- システム全体のアクセスログ管理 → Reliability観点

## Scoring Guidelines

**Full Points (2.0)**: 5つの評価項目すべてに対して具体的な設計が含まれ、規制要件との対応が明示されている

**Partial Points (1.0)**: 5つの項目のうち3つ以上について設計が含まれているが、規制準拠の具体性が不足

**Zero Points (0.0)**: データプライバシーに関する記述が皆無、または1-2項目のみで不十分

## Bonus/Penalty

**Bonus (+0.5)**: Privacy by Design原則の明示的適用、データ保持期間の自動削除設計、クロスボーダーデータ転送の考慮

**Penalty (-0.5)**: データ保護影響評価(DPIA)が必要な高リスクケースで評価が欠如、削除権実装の欠如
```

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T01-C1 | Value contribution identification | 観点なしで見逃される3つ以上の具体的問題を列挙し、各問題が修正可能な改善に繋がることを確認 | 見逃される問題を列挙するが2つ以下、または改善可能性の検証が不足 | 問題列挙が抽象的または見逃される問題の特定なし | 1.0 |
| T01-C2 | Boundary overlap detection | 「データアクセス制御」と「システム全体のアクセスログ管理」の範囲曖昧性を指摘 | アクセス関連の曖昧性に言及するが具体的な重複項目を特定せず | 境界曖昧性を検出せず | 1.0 |
| T01-C3 | Cross-reference verification | Security観点への参照が適切か検証(認証・暗号化がSecurity観点に含まれるか確認) | 参照先の確認に言及するが検証手順が不明確 | 相互参照の検証なし | 0.5 |
| T01-C4 | Actionability assessment | 5つのスコープ項目が具体的改善に繋がるか評価し、「注意すべき」で終わる指摘がないことを確認 | 実行可能性に言及するがスコープ項目との対応が不明確 | 実行可能性の評価なし | 0.5 |

#### Expected Key Behaviors
- 観点の主要目的「個人情報保護とプライバシー要件の評価」を1文で要約
- スコープ5項目それぞれが検証する内容を明確化
- 「データアクセス制御」(in-scope)と「アクセスログ管理」(out-of-scope, Reliabilityに委譲)の境界曖昧性を検出
- GDPR準拠チェック、削除権実装、匿名化戦略等の具体的問題を列挙

#### Anti-patterns
- 境界曖昧性を見逃す
- 抽象的な問題列挙(「プライバシーリスクがある」等)で修正可能性を検証しない
- 相互参照の検証をスキップ

---

### T02: Significant Scope Overlap with Existing Perspective

**Difficulty**: Medium
**Category**: Boundary verification + Cross-reference accuracy

#### Input

Perspective definition file to evaluate:

```markdown
# Perspective: API Design Quality

## Purpose
評価対象の設計書において、API設計が明確で一貫性があり、利用しやすいかを評価します。

## Evaluation Scope
このパースペクティブでは以下を評価します:
1. RESTful原則への準拠(リソース指向、HTTPメソッド適切性)
2. エンドポイント命名規則の一貫性
3. リクエスト/レスポンスのデータ構造明確性
4. エラーレスポンス形式の統一性
5. APIバージョニング戦略の明確性

## Out of Scope
以下は本パースペクティブの範囲外です:
- API認証・認可メカニズム → Security観点
- レート制限やキャッシュ戦略 → Performance観点
- APIドキュメント生成ツールの選定 → Best Practices観点

## Scoring Guidelines

**Full Points (2.0)**: 5つの評価項目すべてに対して具体的設計があり、統一された原則に基づいている

**Partial Points (1.0)**: 3つ以上の項目について設計があるが、一貫性が部分的に欠如

**Zero Points (0.0)**: API設計に関する記述が不十分、または統一性が全く見られない

## Bonus/Penalty

**Bonus (+0.5)**: OpenAPI仕様の採用、ハイパーメディアコントロール(HATEOAS)の活用、後方互換性保証の明示

**Penalty (-0.5)**: HTTPステータスコードの誤用、破壊的変更の予防策なし
```

Existing perspectives summary:
- **Consistency**: 命名規則、データ構造、エラーハンドリングパターンの一貫性を評価
- **Best Practices**: 業界標準の採用、ドキュメント充実度、保守性のベストプラクティスを評価
- **Security**: 認証、認可、入力検証、暗号化を評価
- **Performance**: レスポンスタイム、スループット、リソース効率を評価

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T02-C1 | Scope overlap detection | 「命名規則一貫性」「エラーレスポンス統一性」がConsistency観点と重複することを具体的に指摘 | 一貫性関連の重複に言及するが具体的項目を特定せず | スコープ重複を検出せず | 1.0 |
| T02-C2 | Overlap with Best Practices | 「OpenAPI仕様採用」「ドキュメント生成ツール選定」がBest Practices観点と重複する可能性を指摘 | Best Practices観点との関連に言及するが重複の具体性不足 | Best Practicesとの重複を見逃す | 1.0 |
| T02-C3 | Critical boundary issue identification | 複数観点との重複により観点の独自性が不明確であることを「重大な問題」として判定 | 重複を指摘するが重大性の判断が不明確 | 重複を軽微な問題として扱う | 1.0 |
| T02-C4 | Refactoring recommendation | スコープを「RESTful設計原則」に限定しConsistency/Best Practicesに委譲する具体的改善提案 | 改善提案があるが実行可能性が不明確 | 改善提案なし | 1.0 |

#### Expected Key Behaviors
- Consistency観点との「命名規則」「エラー形式統一」の重複を検出
- Best Practices観点との「OpenAPI採用」「ドキュメント」の重複可能性を検出
- 複数重複により観点の独自性が不足していることを「重大な問題」と判定
- RESTful原則に焦点を絞る等の具体的リファクタリング提案

#### Anti-patterns
- 重複を「改善提案」レベルで留める(重大性を見逃す)
- 抽象的な提案(「スコープを見直すべき」)で具体的委譲先を示さない
- Best Practices観点との重複可能性を見落とす

---

### T03: Overly Narrow Scope Limiting Usefulness

**Difficulty**: Medium
**Category**: Scope appropriateness + Value contribution

#### Input

Perspective definition file to evaluate:

```markdown
# Perspective: Database Index Optimization

## Purpose
評価対象の設計書において、データベースインデックス設計が適切に計画されているかを評価します。

## Evaluation Scope
このパースペクティブでは以下を評価します:
1. プライマリキー・外部キーインデックスの定義
2. 検索クエリパターンに基づくインデックス設計
3. 複合インデックスの適切性
4. インデックスメンテナンス計画(再構築、統計更新)
5. インデックス肥大化への対策

## Out of Scope
以下は本パースペクティブの範囲外です:
- クエリ最適化戦略 → Performance観点
- データモデル設計 → Best Practices観点
- バックアップリストア手順 → Reliability観点

## Scoring Guidelines

**Full Points (2.0)**: 5つの項目すべてに具体的なインデックス設計が含まれ、クエリパターンとの対応が明示

**Partial Points (1.0)**: 3つ以上の項目に設計があるがクエリパターンとの対応が不明確

**Zero Points (0.0)**: インデックス設計の記述が不十分または皆無

## Bonus/Penalty

**Bonus (+0.5)**: パーティショニングとの組み合わせ、カバリングインデックスの活用、インデックスヒント戦略

**Penalty (-0.5)**: 不要インデックスによる更新性能劣化リスクの未考慮、統計情報更新の欠如
```

Existing perspectives:
- **Performance**: レスポンスタイム、スループット、スケーラビリティ、クエリ最適化を評価
- **Best Practices**: データモデリング、コード品質、保守性を評価

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T03-C1 | Narrow scope identification | スコープがデータベース設計の一部分(インデックスのみ)に限定され過ぎていることを指摘 | 狭隘性に言及するが具体的範囲の問題を特定せず | 狭隘性を検出せず | 1.0 |
| T03-C2 | Performance overlap analysis | 「検索クエリパターン」「複合インデックス」がPerformance観点のクエリ最適化と重複することを指摘 | Performance観点との関連に言及するが重複の具体性不足 | Performance観点との重複を見逃す | 1.0 |
| T03-C3 | Value limitation assessment | インデックス設計のみでは見逃される重要な問題(データモデル設計、正規化、パーティション戦略等)を列挙 | 見逃される問題に言及するが具体性不足 | 観点の価値制限を評価せず | 1.0 |
| T03-C4 | Scope expansion recommendation | Performance観点に統合しデータベース最適化全般に拡張する、または独立性を保つ明確な理由を提示する具体的提案 | 改善提案があるが統合/拡張の判断基準が不明確 | 改善提案なし | 1.0 |

#### Expected Key Behaviors
- インデックスのみに限定された狭隘なスコープを検出
- Performance観点の「クエリ最適化」との境界曖昧性を指摘
- データモデル設計、パーティション戦略等の見逃される重要問題を列挙
- Performance観点への統合または明確な独立理由を提示する提案

#### Anti-patterns
- 狭隘性を「確認(良い点)」として評価(焦点が絞られている、として誤評価)
- Performance観点との関係性を分析しない
- スコープ拡張の具体的方向性を示さない

---

### T04: Ambiguous Cross-Reference and Verification Gaps

**Difficulty**: Hard
**Category**: Cross-reference accuracy + Boundary verification

#### Input

Perspective definition file to evaluate:

```markdown
# Perspective: User Experience

## Purpose
評価対象の設計書において、エンドユーザー体験が考慮され、使いやすいシステムとなっているかを評価します。

## Evaluation Scope
このパースペクティブでは以下を評価します:
1. ユーザー操作フローの明確性と直感性
2. エラーメッセージの分かりやすさと回復ガイダンス
3. アクセシビリティ要件(WCAG準拠)の考慮
4. レスポンス時間とユーザー待機時間の設計
5. 多言語・多地域対応の考慮

## Out of Scope
以下は本パースペクティブの範囲外です:
- UIコンポーネントの実装詳細 → Best Practices観点
- システムエラーログの詳細設計 → Monitoring観点
- バックエンド処理のパフォーマンス → Performance観点
- データ検証ルール → Validation観点

## Scoring Guidelines

**Full Points (2.0)**: 5つの項目すべてに具体的設計があり、ユーザー中心設計の原則が明示

**Partial Points (1.0)**: 3つ以上の項目に設計があるがユーザー視点の具体性が不足

**Zero Points (0.0)**: UXに関する記述が不十分

## Bonus/Penalty

**Bonus (+0.5)**: ユーザビリティテスト計画の明示、プログレスフィードバック設計、ヘルプ・ガイダンス機能

**Penalty (-0.5)**: 複雑な操作フローに対するガイダンス不足、アクセシビリティ考慮の欠如
```

Existing perspectives:
- **Consistency**: エラーメッセージ形式、命名規則、UI/UXパターンの一貫性を評価
- **Performance**: レスポンスタイム、スループット、スケーラビリティを評価
- **Best Practices**: コード品質、テスト戦略、ドキュメント、保守性を評価

Note: Monitoring観点とValidation観点は存在しない

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T04-C1 | Invalid cross-reference detection | 「Monitoring観点」「Validation観点」が存在しないことを検出し、参照エラーとして指摘 | 存在しない観点への言及があるが検証せず | 無効な参照を見逃す | 1.0 |
| T04-C2 | Consistency overlap detection | 「エラーメッセージの分かりやすさ」がConsistency観点の「エラーメッセージ形式」と重複/境界曖昧であることを指摘 | エラーメッセージ関連の重複に言及するが具体的境界を分析せず | Consistencyとの重複を見逃す | 1.0 |
| T04-C3 | Performance overlap analysis | 「レスポンス時間設計」がPerformance観点と重複することを指摘し、どちらがユーザー視点/システム視点かの境界を明確化する必要性を提示 | Performance観点との関連に言及するが境界明確化の必要性を示さず | Performanceとの重複を見逃す | 1.0 |
| T04-C4 | Critical issue determination | 無効参照と複数重複により観点定義に重大な問題があると判定 | 問題を指摘するが重大性の判断が不明確 | 問題を軽微として扱う | 1.0 |
| T04-C5 | Corrective recommendations | 無効参照の削除、エラーメッセージ範囲の明確化(ユーザー向けメッセージのみ)、レスポンス時間の委譲を含む具体的改善提案 | 改善提案があるが実行可能性が不明確 | 改善提案なし | 1.0 |

#### Expected Key Behaviors
- 存在しない「Monitoring観点」「Validation観点」への参照を検出
- Consistency観点との「エラーメッセージ」領域の境界曖昧性を指摘
- Performance観点との「レスポンス時間」の重複と境界明確化の必要性を提示
- 無効参照+複数重複により「重大な問題」と判定
- 無効参照削除、境界明確化、委譲の具体的提案

#### Anti-patterns
- 存在しない観点への参照を検証しない
- エラーメッセージやレスポンス時間の重複を見逃す
- 問題を「改善提案」レベルで扱う(重大性を見逃す)
- 抽象的な提案で具体的修正内容を示さない

---

### T05: Well-Defined Perspective with Good Boundaries

**Difficulty**: Easy
**Category**: Value contribution + Boundary verification + Actionability

#### Input

Perspective definition file to evaluate:

```markdown
# Perspective: Observability

## Purpose
評価対象の設計書において、システムの内部状態を可視化し、問題の迅速な検出と診断を可能にする設計が含まれているかを評価します。

## Evaluation Scope
このパースペクティブでは以下を評価します:
1. 構造化ログ設計(ログレベル、ログフォーマット、コンテキスト情報)
2. メトリクス収集設計(ビジネスメトリクス、システムメトリクス、SLI定義)
3. 分散トレーシング設計(トレースID伝播、スパン設計)
4. ヘルスチェックとレディネスプローブの設計
5. アラート閾値と通知戦略の明確性

## Out of Scope
以下は本パースペクティブの範囲外です:
- 監視ツール製品の選定(Prometheus vs Datadog等) → Best Practices観点
- ログ保管期間やストレージ容量計画 → Reliability観点
- エラーハンドリングとリトライロジック → Reliability観点
- セキュリティログと監査証跡 → Security観点

## Scoring Guidelines

**Full Points (2.0)**: 5つの項目すべてに具体的設計があり、可観測性の3本柱(ログ・メトリクス・トレース)が揃っている

**Partial Points (1.0)**: 3つ以上の項目に設計があるが、3本柱のいずれかが欠如

**Zero Points (0.0)**: 可観測性に関する記述が不十分または皆無

## Bonus/Penalty

**Bonus (+0.5)**: SLO/SLI/SLAの明確な定義、カスタムダッシュボード設計、相関分析の考慮

**Penalty (-0.5)**: ログレベルの不適切な使用、メトリクス収集のオーバーヘッド未考慮、アラート疲労のリスク
```

Existing perspectives:
- **Reliability**: エラーハンドリング、リトライ、フォールバック、データ整合性、障害復旧を評価
- **Security**: 認証、認可、暗号化、監査証跡を評価
- **Best Practices**: ツール選定、コード品質、保守性を評価

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T05-C1 | Clear value proposition | 観点なしで見逃される3つ以上の具体的問題(構造化ログ欠如、メトリクス不足、トレースID欠如等)を列挙 | 見逃される問題を列挙するが2つ以下 | 問題列挙が抽象的 | 1.0 |
| T05-C2 | Clear boundary with Reliability | エラーハンドリング/リトライがReliability観点に委譲され、境界が明確であることを確認 | 境界に言及するが明確性の評価が不足 | 境界確認なし | 1.0 |
| T05-C3 | Clear boundary with Security | 監査証跡がSecurity観点に委譲され、可観測性は運用診断に焦点を絞っていることを確認 | 境界に言及するが焦点の明確性が不足 | 境界確認なし | 1.0 |
| T05-C4 | Actionability confirmation | 5つのスコープ項目すべてが具体的改善(ログ追加、メトリクス定義、トレースID実装等)に繋がることを確認 | 実行可能性に言及するが項目との対応が不明確 | 実行可能性の評価なし | 0.5 |
| T05-C5 | Positive assessment | 重大な問題がなく、観点が有効であることを「確認(良い点)」として評価 | 肯定的評価があるが根拠が不明確 | 肯定的評価なし | 0.5 |

#### Expected Key Behaviors
- 構造化ログ欠如、SLI未定義、トレースID欠如等の具体的問題を列挙
- Reliability観点との境界が明確(エラーハンドリング委譲)であることを確認
- Security観点との境界が明確(監査証跡委譲)であることを確認
- 5つのスコープ項目が修正可能な具体的改善に繋がることを確認
- 重大な問題なし、境界明確、実行可能、として「確認(良い点)」で評価

#### Anti-patterns
- 境界確認を省略
- 抽象的な問題列挙(「可視性が不足する」等)
- 良い観点に対して改善提案を無理に生成

---

### T06: Actionability Issues - Recognition Without Improvement

**Difficulty**: Hard
**Category**: Actionability + Value contribution

#### Input

Perspective definition file to evaluate:

```markdown
# Perspective: Complexity Management

## Purpose
評価対象の設計書において、システム複雑性が適切に管理され、保守性が確保されているかを評価します。

## Evaluation Scope
このパースペクティブでは以下を評価します:
1. システム全体のアーキテクチャ複雑性の認識
2. モジュール間結合度の高い領域の特定
3. 循環依存のリスクがある設計の識別
4. 技術的負債の蓄積リスクの評価
5. 将来の拡張性への影響の考慮

## Out of Scope
以下は本パースペクティブの範囲外です:
- 具体的なリファクタリング手法 → Best Practices観点
- コード品質メトリクス(サイクロマティック複雑度等) → Best Practices観点
- パフォーマンスへの影響 → Performance観点

## Scoring Guidelines

**Full Points (2.0)**: 5つの項目すべてについて複雑性の認識と評価が含まれている

**Partial Points (1.0)**: 3つ以上の項目について認識があるが具体性が不足

**Zero Points (0.0)**: 複雑性管理に関する記述が不十分

## Bonus/Penalty

**Bonus (+0.5)**: 複雑性の定量的指標の活用、複雑性削減の優先順位付け、境界コンテキストの明確化

**Penalty (-0.5)**: 過度に複雑な設計の放置、モジュール分割の欠如
```

Existing perspectives:
- **Best Practices**: コード品質、リファクタリング、保守性、テスト戦略を評価
- **Performance**: レスポンスタイム、スループット、スケーラビリティを評価

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T06-C1 | Non-actionable pattern detection | スコープ5項目が「認識」「特定」「識別」「評価」「考慮」という非行動的動詞で構成され、具体的改善に繋がらないパターンを検出 | 非行動的パターンに言及するが全項目の体系的分析なし | 非行動的パターンを検出せず | 1.0 |
| T06-C2 | Scoring guideline mismatch | Scoring Guidelinesが「認識があること」を評価基準としており、改善実施を求めていない不整合を指摘 | 評価基準の問題に言及するが具体的不整合を特定せず | 評価基準の問題を見逃す | 1.0 |
| T06-C3 | Value limitation due to non-actionability | 「複雑性があることを認識せよ」で終わる指摘はレビュー価値が限定的であることを指摘 | 価値制限に言及するが根拠が不明確 | 価値制限を評価せず | 1.0 |
| T06-C4 | Best Practices overlap analysis | 「保守性」「技術的負債」「拡張性」がBest Practices観点と重複することを指摘 | Best Practices観点との関連に言及するが重複の具体性不足 | Best Practicesとの重複を見逃す | 1.0 |
| T06-C5 | Actionable refactoring recommendation | スコープを「循環依存の検出と解消策の提示」「モジュール分割の具体的提案」等の行動的項目に変更する具体的提案 | 改善提案があるが行動可能性の確保が不明確 | 改善提案なし | 1.0 |

#### Expected Key Behaviors
- スコープ5項目が非行動的動詞(認識/特定/識別/評価/考慮)で構成されていることを検出
- Scoring Guidelinesが「認識があること」を評価しており改善実施を求めていない不整合を指摘
- 「認識のみ」の指摘はレビュー価値が限定的であることを指摘
- Best Practices観点との「保守性」「技術的負債」の重複を指摘
- 行動的項目(解消策提示、具体的提案等)への変更を提案

#### Anti-patterns
- 非行動的パターンを見逃す
- 「認識があること」を肯定的に評価
- Best Practices観点との重複を分析しない
- 抽象的な改善提案で行動可能性を確保しない

---

### T07: Vague Value Proposition and Unclear Scope

**Difficulty**: Medium
**Category**: Value contribution + Scope appropriateness

#### Input

Perspective definition file to evaluate:

```markdown
# Perspective: Technical Debt Awareness

## Purpose
評価対象の設計書において、技術的負債の蓄積リスクが考慮されているかを評価します。

## Evaluation Scope
このパースペクティブでは以下を評価します:
1. 短期的解決策と長期的影響のトレードオフ認識
2. 既知の制約や妥協点の文書化
3. 将来のリファクタリング機会の特定
4. レガシーシステムとの統合における負債の評価

## Out of Scope
以下は本パースペクティブの範囲外です:
- 具体的なリファクタリング計画 → Best Practices観点
- コード品質の詳細評価 → Best Practices観点

## Scoring Guidelines

**Full Points (2.0)**: 4つの項目すべてについて技術的負債の認識が含まれている

**Partial Points (1.0)**: 2つ以上の項目について認識があるが具体性が不足

**Zero Points (0.0)**: 技術的負債に関する記述が不十分

## Bonus/Penalty

**Bonus (+0.5)**: 負債の定量化、返済計画、優先順位付け

**Penalty (-0.5)**: 意図的な妥協点が文書化されていない
```

Existing perspectives:
- **Best Practices**: コード品質、リファクタリング、保守性、テスト戦略を評価

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T07-C1 | Vague value proposition detection | 「技術的負債の蓄積リスクが考慮されているか」という目的が曖昧で、観点なしで見逃される具体的問題が不明であることを指摘 | 目的の曖昧性に言及するが具体的問題の欠如を指摘せず | 目的の曖昧性を検出せず | 1.0 |
| T07-C2 | Non-actionable scope analysis | スコープ4項目が「認識」「文書化」「特定」「評価」で構成され、T06と同様の非行動的パターンであることを指摘 | 非行動的パターンに言及するが項目との対応が不明確 | 非行動的パターンを検出せず | 1.0 |
| T07-C3 | Best Practices complete overlap | スコープ全体(リファクタリング、レガシー統合、コード品質)がBest Practices観点と完全に重複し独自性がないことを指摘 | Best Practices観点との重複に言及するが完全重複の指摘なし | Best Practicesとの重複を見逃す | 1.0 |
| T07-C4 | Insufficient item count | スコープが4項目のみで、他の観点の標準5項目より少なく網羅性が不足していることを指摘 | 項目数に言及するが網羅性への影響を評価せず | 項目数の問題を見逃す | 0.5 |
| T07-C5 | Critical issue determination and recommendation | Best Practices観点への統合または観点の廃止を「重大な問題」として提案 | 統合/廃止に言及するが重大性の判断が不明確 | 統合/廃止の提案なし | 1.0 |

#### Expected Key Behaviors
- 目的が曖昧で観点なしで見逃される具体的問題が不明であることを指摘
- スコープ4項目が非行動的動詞で構成されていることを指摘
- Best Practices観点とのスコープ完全重複により独自性がないことを指摘
- 項目数が標準5項目より少なく網羅性不足であることを指摘
- Best Practices観点への統合または観点廃止を「重大な問題」として提案

#### Anti-patterns
- 目的の曖昧性を見逃す
- Best Practices観点との完全重複を部分重複として扱う
- 項目数の少なさを指摘しない
- 問題を「改善提案」レベルで扱う(重大性を見逃す)
