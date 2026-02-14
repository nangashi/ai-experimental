# スコープ整合性分析 (Scope Alignment)

- agent_name: api-design-reviewer
- analyzed_at: 2026-02-12

## スコープ評価テーブル
| 観点 | 評価 | 判定 |
|------|------|------|
| スコープ定義品質 | IMPLICIT | 要改善 |
| スコープ外文書化 | ABSENT | 問題あり |
| 境界明確性 | UNDEFINED | 問題あり |
| 内部整合性 | CONTRADICTORY | 問題あり |
| スコープ適切性 | TOO_BROAD | 要改善 |
| 基準-ドメインカバレッジ | BOTH | 要改善 |

## Findings

### SA-01: スコープ定義が暗黙的で操作的に不明瞭 [severity: improvement]
- 内容: "Evaluation Scope"セクションは存在するが、「API endpoint design, request/response formats, and integration patterns」という記述のみで具体的なカテゴリ列挙がない。評価範囲は基準から推測可能だが、明示的な列挙がないため境界が曖昧。
- 根拠: Line 10の"This agent reviews API endpoint design, request/response formats, and integration patterns"は抽象的な記述であり、具体的な評価カテゴリ（例: RESTful design, error handling, authentication等）の列挙がない。
- 推奨: Evaluation Scopeセクションで評価対象を具体的に列挙する（例: "Covers: RESTful design compliance, error handling, authentication design, performance characteristics, data validation, API documentation, integration testing design"）。

### SA-02: スコープ外領域の文書化が完全に欠如 [severity: improvement]
- 内容: Out-of-scopeの記述が一切なく、他エージェントとの責任分担が不明。APIレビューと隣接する領域（例: 実装品質レビュー、運用監視設計、インフラセキュリティ等）との境界が文書化されていない。
- 根拠: 文書全体でout-of-scope/cross-reference/adjacent domainに関する記述が存在しない。
- 推奨: "Out of Scope"セクションを追加し、隣接領域と担当エージェントを明記する（例: "Out of scope: API implementation code quality (→ code-reviewer), infrastructure security configuration (→ infra-security-reviewer), database schema design (→ data-design-reviewer)"）。

### SA-03: 隣接ドメインとの境界が未定義で重複リスクが高い [severity: improvement]
- 内容: Criterion 3 "Authentication & Security"とCriterion 4 "Performance & Scalability"は他の専門レビューア（security-reviewer, performance-reviewer）と重複する可能性が高いが、境界が明示されていない。"gray zone"の扱いが不明瞭。
- 根拠: Line 32-40（Authentication & Security）とLine 42-47（Performance & Scalability）は専門ドメインと重複する評価項目を含むが、どのレベルまでこのエージェントが評価し、詳細はどこに委譲するのかが記載されていない。
- 推奨: 各基準に境界注記を追加する（例: "Note: This criterion evaluates API-level security design. Infrastructure security (firewall, network policies) and detailed threat modeling are handled by security-reviewer."）。

### SA-04: スコープ記述と評価基準の間に重大な矛盾が存在 [severity: critical]
- 内容: Criterion 3の"All API endpoints must include authentication mechanisms"（Line 32）と"Public-facing APIs should remain accessible without requiring authentication"（Line 34-35）は直接矛盾している。評価時に一貫性のない判定を引き起こす。
- 根拠: Line 32は認証必須を要求し、Line 34-35は認証不要を推奨しており、同一基準内で相反する指示が共存している。
- 推奨: 矛盾を解消し、条件分岐を明確にする（例: "Internal APIs must include authentication. Public APIs may be accessible without authentication if explicitly documented as public endpoints with appropriate rate limiting."）。

### SA-05: Criterion 4にスコープを超える実行可能性のない要求が含まれる [severity: critical]
- 内容: "API can handle expected load conditions under all possible traffic scenarios"（Line 45-46）は設計文書レビューの範囲を超え、実行時パフォーマンステスト/負荷試験の領域に入っている。設計文書段階では検証不可能。
- 根拠: Line 45-46は"under all possible traffic scenarios"という実行時の包括的検証を要求しているが、Overview（Line 6）は"Evaluates API design documents"と明記しており、設計文書の静的レビューがスコープ。
- 推奨: 実行可能な設計レビュー基準に修正する（例: "Design includes load estimation and scalability considerations (expected traffic patterns, peak load scenarios documented)"）。パフォーマンステストは別エージェント（performance-tester）に委譲。

### SA-06: Criterion 6にスコープを超える実行不可能な要求が含まれる [severity: critical]
- 内容: "Tracing all API call chains across all microservices to verify documentation consistency"（Line 59）は設計文書レビューの範囲を大きく超え、システム全体のアーキテクチャ分析・実装検証を要求している。
- 根拠: Line 59は全マイクロサービスの実装を横断するトレース実行を要求しているが、これは設計文書レビューでは不可能。Overviewは"design documents"のレビューと明記している。
- 推奨: 設計文書段階で実行可能な基準に修正する（例: "API documentation references dependencies and integration points with other services"）。実装レベルの整合性検証は別エージェント（integration-reviewer）に委譲。

### SA-07: Criterion 7が実行型タスクを要求しレビューの範囲を逸脱 [severity: critical]
- 内容: "Verify API integration quality by executing API calls to verify response correctness"（Line 63）は設計レビューではなく統合テストの実行を要求している。エージェントの役割と矛盾。
- 根拠: Line 63は"executing API calls"を明示的に要求しているが、Description（Line 3）は"Evaluates API design documents"であり、実行型テストはスコープ外。
- 推奨: 設計レビュー基準に修正する（例: "Design includes integration test scenarios covering critical user flows and mock service configurations"）。実際のテスト実行は別エージェント（integration-tester）に委譲。

### SA-08: スコープが広すぎて深度の薄い分析リスクがある [severity: improvement]
- 内容: 7つの評価基準がREST設計、エラーハンドリング、セキュリティ、パフォーマンス、データ検証、文書化、統合テストと多岐にわたり、各専門ドメインの表層のみをカバーする懸念がある。
- 根拠: Criterion 3（Security）とCriterion 4（Performance）は専門レビューアの存在を前提とする領域であり、API設計レビューアが深掘りするには範囲が広すぎる。
- 推奨: スコープをAPI設計固有の領域（REST compliance, endpoint design, request/response schema, API documentation）に絞り込み、Security/Performanceは専門レビューアに完全委譲するか、"API-level surface checks only"と明示する。

### SA-09: 目的記述から期待されるドメイン領域に対する基準カバレッジに偏りと欠落がある [severity: improvement]
- 内容: 目的記述"Evaluates API design documents for compliance with REST principles, consistency, and quality standards"から期待される領域: (A)REST compliance, (B)Consistency, (C)Quality standards。しかし基準のマッピングは以下の通り:
  - (A)REST compliance: Criterion 1のみ
  - (B)Consistency: Criterion 6の一部のみ（API間の一貫性、命名規則の一貫性等に対する明示的基準なし）
  - (C)Quality standards: Criterion 2,3,4,5,7に分散
  また、目的に含まれない領域（Integration testing execution）が基準に含まれている（Criterion 7）。
- 根拠: Line 3のdescriptionは"REST principles, consistency, and quality standards"を挙げているが、"consistency"に対応する独立した基準が存在しない。Criterion 6（Line 59）の"documentation consistency"は文書の整合性であり、API設計の一貫性（命名規則、エラーフォーマット統一等）ではない。
- 推奨: "Consistency"ドメインに対応する独立基準を追加する（例: "API Consistency: Naming conventions, error format consistency across endpoints, HTTP status code usage consistency"）。Integration testing executionは削除またはout-of-scopeに移動。

### SA-10: Criterion 5の記述が曖昧で評価対象が不明瞭 [severity: improvement]
- 内容: "Check for potential API issues that might arise in future versions"（Line 50）は時間軸が不明瞭で、何を評価すればよいか判断できない。また"Following the project's API validation guidelines"（Line 52）は外部依存で基準として不完全。
- 根拠: Line 50は"future versions"という不確定要素を評価対象としているが、具体的にどの側面（後方互換性、拡張性等）を見るのか不明。Line 52は"project's guidelines"への参照のみで、ガイドラインが存在しない場合評価不可能。
- 推奨: 現在のバージョンで評価可能な具体的基準に修正する（例: "Input validation rules are explicitly defined with schema (JSON Schema or equivalent). Required fields, data types, format constraints, and range validations are documented."）。

## Summary

- critical: 4
- improvement: 6
- info: 0
