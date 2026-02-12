# スコープ整合性分析 (Scope Alignment)

- agent_name: api-design-reviewer
- analyzed_at: 2026-02-12

## スコープ評価テーブル
| 観点 | 評価 | 判定 |
|------|------|------|
| スコープ定義品質 | EXPLICIT | 適切 |
| スコープ外文書化 | ABSENT | 問題あり |
| 境界明確性 | UNDEFINED | 問題あり |
| 内部整合性 | MINOR_DEVIATION | 要改善 |
| スコープ適切性 | TOO_BROAD | 要改善 |
| 基準-ドメインカバレッジ | BOTH | 要改善 |

## Findings

### SA-01: スコープ外領域が文書化されていない [severity: improvement]
- 内容: エージェント定義に out-of-scope の明示的な文書化が存在しない。API デザインレビューアとして何を評価「しない」のか、どの領域が他のレビューアの責任なのかが不明。
- 根拠: 定義全体を確認したが、「Out of Scope」「Not covered」「Other reviewers」などのセクションや記述が存在しない。
- 推奨: Out-of-scope セクションを追加し、以下を明記する: (1) インフラ構成の詳細（インフラレビューアが担当）、(2) データベーススキーマ設計（データモデリングレビューアが担当）、(3) フロントエンド UI/UX（UI/UXレビューアが担当）、(4) ビジネスロジックの正確性（ドメインエキスパートが担当）等

### SA-02: 隣接ドメインとの境界が未定義 [severity: improvement]
- 内容: セキュリティ、パフォーマンス、エラーハンドリング等の「グレーゾーン」トピックについて、どのレビューアが「所有」するのか明確でない。
- 根拠:
  - 「3. Authentication & Security」でセキュリティ観点を評価するが、専門のセキュリティレビューアとの責任分界が不明
  - 「4. Performance & Scalability」でパフォーマンス観点を評価するが、専門のパフォーマンスレビューアとの分担が不明
  - 「2. Error Handling Design」でエラーハンドリングを評価するが、信頼性レビューアとの重複可能性がある
- 推奨: 各基準に対して「API デザイン観点でのチェック」と「専門レビューアへのエスカレーション基準」を明記する。例: 「Authentication & Security では API 設計としての認証メカニズムの存在を確認するが、暗号化アルゴリズムの適切性や脆弱性診断は security-reviewer が担当」

### SA-03: スコープ記述と評価基準の不整合 [severity: improvement]
- 内容: Evaluation Scope では「API endpoint design, request/response formats, and integration patterns」のみを対象とするが、実際の評価基準は実装詳細（実行による検証）やインフラ側の責任領域まで含む。
- 根拠:
  - Scope: "API endpoint design, request/response formats, and integration patterns"（設計レベル）
  - 基準 7「Integration Testing Design」: "executing API calls to verify response correctness"（実装・実行レベルの検証を要求）
  - 基準 4「Performance & Scalability」: "API can handle expected load conditions under all possible traffic scenarios"（インフラ・負荷試験レベルの要求）
- 推奨: スコープを「API design and contract specification」に明確化し、実装検証・負荷試験はスコープ外として out-of-scope セクションに記載する。または、スコープを「API design and implementation review」に拡大して整合させる。

### SA-04: スコープが過度に広範 [severity: improvement]
- 内容: エージェントが REST 準拠、エラーハンドリング、セキュリティ、パフォーマンス、バリデーション、ドキュメント、統合テストという 7 つの異なる側面を同時にカバーしており、各領域の分析が浅くなるリスクがある。
- 根拠:
  - 7 つの評価基準が存在し、それぞれが独立した専門領域（セキュリティ、パフォーマンス等）を含む
  - 「all possible traffic scenarios」「all microservices」「critical user flows」など、包括的すぎる記述が散見される
- 推奨: スコープを「API contract design and REST compliance」に焦点化し、セキュリティ・パフォーマンス・統合テストの詳細評価は専門レビューアに委譲する。または、これらを別の focused なレビューアに分割する（例: api-contract-reviewer + api-security-reviewer）。

### SA-05: ドメイン領域のカバレッジギャップと過剰 [severity: improvement]
- 内容: エージェントの目的「API design documents for REST principles, consistency, and quality standards」から期待されるドメイン領域のうち、一部が評価基準でカバーされておらず、逆にスコープ外の領域を評価している。
- 根拠:
  - **カバレッジギャップ（不足）**:
    - "consistency"（一貫性）: 目的に明記されているが、対応する評価基準が存在しない。基準 1 で命名規則に触れるのみで、エンドポイント間の設計一貫性、レスポンス形式の統一性等の体系的チェックがない
    - "quality standards"（品質基準）: 抽象的な記述だが、SLA 定義、可観測性（ロギング・メトリクス）、後方互換性等の具体的な品質側面への基準が欠落
  - **過剰（目的外の基準）**:
    - 基準 7「Integration Testing Design」: 統合テスト設計は API デザインレビューのスコープではなく、QA/テスト戦略レビューの領域
    - 基準 4 の負荷試験要件: 「under all possible traffic scenarios」は API 設計ではなくインフラ・負荷試験の領域
  - **偏り**: セキュリティ（基準 3）とパフォーマンス（基準 4）に詳細な基準があるが、consistency と quality standards の基準が薄い
- 推奨:
  1. "API Consistency" 基準を追加: エンドポイント間の命名統一、レスポンス形式の一貫性、エラーコード体系の統一をチェック
  2. "Quality Standards Compliance" 基準を追加: SLA 定義の有無、可観測性設計（ロギング・メトリクス・トレーシング）、後方互換性保証の設計をチェック
  3. 基準 7（Integration Testing）を削除し、out-of-scope として QA レビューアに委譲
  4. 基準 4 の負荷試験要件を削除し、「ページネーション設計の有無」等の設計レベルのチェックに限定

### SA-06: 評価基準内の矛盾した指示 [severity: critical]
- 内容: 基準 3「Authentication & Security」に直接矛盾する 2 つの要求が含まれており、エージェントが一貫性のない判断を下すリスクがある。
- 根拠:
  - 1 文目: "All API endpoints must include authentication mechanisms. Flag any endpoint that lacks proper authentication."（全エンドポイントに認証必須）
  - 2 文目: "Public-facing APIs should remain accessible without requiring authentication to ensure broad adoption and developer experience."（パブリック API は認証不要であるべき）
  - これらは両立不可能であり、エージェントがどちらを優先すべきか判断できない
- 推奨: 矛盾を解消するため、以下のように書き換える: 「機密データを扱うエンドポイントは認証を必須とする。パブリック読み取り専用エンドポイント（例: 公開 API ドキュメント、ヘルスチェック）は認証なしでアクセス可能として設計してもよいが、その場合はレート制限を必須とする」

### SA-07: 評価基準の曖昧で実行不可能な指示 [severity: improvement]
- 内容: 複数の評価基準に「適切」「ベストプラクティス」「業界標準」といった曖昧な用語が使用されており、具体的な判定基準がないため、評価者によって判断が揺れる。
- 根拠:
  - 基準 1: "API design is appropriate for the use case"（何が appropriate か不明）
  - 基準 2: "Error handling follows best practices"（best practices が未定義）
  - 基準 4: "API latency must meet industry-standard performance benchmarks"（具体的な数値基準なし）
  - 基準 5: "Check for potential API issues that might arise in future versions"（何を「potential issues」とするか曖昧）
- 推奨: 各曖昧な表現を具体的なチェック項目に置き換える:
  - 基準 1: "API design uses appropriate HTTP methods for each operation type (idempotent operations use GET/PUT/DELETE, non-idempotent use POST)"
  - 基準 2: "Error responses follow RFC 7807 Problem Details format or equivalent structured error format"
  - 基準 4: "List endpoints implement pagination with maximum page size limit (e.g., 100 items)"
  - 基準 5: "Request schemas include explicit versioning fields and avoid breaking changes without version increment"

### SA-08: 実行不可能な評価要求 [severity: critical]
- 内容: 基準 6「API Documentation & Versioning」が、デザインレビューの範囲を超えた実行レベルの作業を要求している。
- 根拠: "Tracing all API call chains across all microservices to verify documentation consistency"（全マイクロサービス間の全 API 呼び出しチェーンをトレースして文書整合性を検証）— これは静的なデザインレビューでは実行不可能であり、実装完了後の統合テスト段階で行うべき作業。
- 推奨: 基準を「API design documents include complete endpoint specifications (OpenAPI/Swagger) and follow the project's versioning strategy (URL-based versioning such as /v1/, /v2/)」に修正し、実装後の統合検証は out-of-scope として integration-test-reviewer に委譲する。

### SA-09: 実行による検証の混入 [severity: improvement]
- 内容: 基準 7「Integration Testing Design」が「executing API calls to verify response correctness」を要求しているが、これは設計レビューではなく実装検証であり、スコープ不整合を引き起こす。
- 根拠: エージェントの description は「Evaluates API design documents」であり、「design documents」は実装前の仕様を指す。実行による検証は実装完了後の作業であり、設計レビューのスコープ外。
- 推奨: 基準 7 を削除し、out-of-scope として「API implementation verification and integration testing are covered by the integration-test-reviewer and QA team」と明記する。設計レビューでは「Integration test scenarios are documented with expected request/response examples」のみをチェックする。

## Summary

- critical: 2
- improvement: 7
- info: 0
