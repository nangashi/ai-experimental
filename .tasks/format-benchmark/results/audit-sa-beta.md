# スコープ整合性分析 (Scope Alignment)

- agent_name: data-model-reviewer
- analyzed_at: 2026-02-12

## スコープ評価テーブル
| 観点 | 評価 | 判定 |
|------|------|------|
| スコープ定義品質 | EXPLICIT | 適切 |
| スコープ外文書化 | ABSENT | 問題あり |
| 境界明確性 | UNDEFINED | 問題あり |
| 内部整合性 | CONTRADICTORY | 問題あり |
| スコープ適切性 | TOO_BROAD | 要改善 |
| 基準-ドメインカバレッジ | BOTH | 要改善 |

## Findings

### SA-01: スコープ外領域の文書化が完全に欠如 [severity: improvement]
- 内容: エージェント定義には "Evaluation Scope" セクションで対象範囲が明示されているが、スコープ外の領域や他エージェント/ツールへの参照が一切記載されていない。
- 根拠: 定義内に "out-of-scope" や他の責任エージェントへの言及が存在しない。データモデルレビューの境界領域（例: アプリケーションレベルのセキュリティ、インフラストラクチャの詳細、コードレベルの実装品質）について、どこまでがこのエージェントの責任かが不明確。
- 推奨: "## Out of Scope" セクションを追加し、以下を明記する: (1) アプリケーション層のセキュリティ実装（security-reviewer参照）、(2) インフラストラクチャ構成の詳細（infrastructure-reviewer参照）、(3) API実装コードの品質（code-quality-reviewer参照）、(4) ビジネスロジックの妥当性（domain-logic-reviewer参照）

### SA-02: 隣接ドメインとの境界が未定義 [severity: critical]
- 内容: データモデルレビューは複数のドメインと境界を共有するが、重複領域の解決戦略が存在しない。特に "API response format validation" と "infrastructure capacity planning" がスコープに含まれているが、これらは通常APIデザインレビューやインフラレビューの領域である。
- 根拠:
  - Evaluation Scope (line 10) に "API response format validation" が含まれるが、APIデザイン全般とデータモデルの境界が未定義
  - "infrastructure capacity planning" が含まれるが、インフラストラクチャ全般との境界が不明確
  - Section 6 "Referential Integrity in Distributed Systems" では分散システムの一貫性を扱うが、これはシステムアーキテクチャレビューと重複する可能性がある
- 推奨: 境界を明確化するため、各グレーゾーン領域について責任分界を定義する。例: "API response format validation: データ構造の整合性のみをレビュー対象とし、HTTPステータスコードやエンドポイント設計は対象外"、"infrastructure capacity planning: データ増加予測とストレージ要件のみをレビューし、サーバー構成やネットワーク設計は対象外"

### SA-03: 内部整合性の重大な矛盾 - 相反する制約要件 [severity: critical]
- 内容: Section 2 "Data Integrity Constraints" で矛盾する制約要件が記載されている。"All fields must have NOT NULL constraints" と "Optional fields should allow null values" が同一セクション内で並列記述されており、実行不可能な指示となっている。
- 根拠: Line 25-27で、全フィールドがNOT NULL制約を持つべきと述べた直後に、オプショナルフィールドはnullを許可すべきと述べている。これらは論理的に両立しない。
- 推奨: 矛盾を解消し、明確なルールを定義する。例: "Required fields must have NOT NULL constraints. Optional fields should explicitly allow NULL values with documented business justification."

### SA-04: 内部整合性の矛盾 - スコープと基準の不一致 [severity: improvement]
- 内容: Evaluation Scope で宣言された領域のいくつかが、Evaluation Criteria に対応する具体的な基準を持たない。
- 根拠:
  - Scope: "query performance optimization" → Criteria: Section 3で indexing を扱うが、query optimization 手法（クエリリライト、マテリアライズドビュー、パーティショニング戦略の詳細）は不足
  - Scope: "standards compliance" (description line 3) → Criteria: 標準準拠に関する明示的な基準が存在しない（どの標準に準拠すべきか不明）
- 推奨: スコープで宣言した全領域に対応する評価基準を追加するか、スコープ記述を実際の基準に合わせて修正する。

### SA-05: スコープが過度に広範で焦点が散漫 [severity: improvement]
- 内容: データモデル設計の中核（正規化、整合性、リレーション）から、API応答フォーマット、インフラキャパシティプランニング、分散システムの整合性まで、複数の異なる専門領域を1つのエージェントでカバーしようとしている。
- 根拠:
  - Evaluation Scope (line 10): 8つの異なる領域をリストアップ
  - Section 6では分散システム特有の複雑な課題（cross-shard references, eventual consistency）を扱う
  - これらの領域はそれぞれ深い専門知識を必要とし、1つのエージェントでカバーすると浅い分析になるリスクがある
- 推奨: スコープを以下に限定することを検討: (1) データベーススキーマ設計（正規化、リレーション、命名規則）、(2) データ整合性制約（外部キー、unique、check制約）、(3) 基本的なインデックス戦略。API、インフラ、分散システムの詳細は専門のレビューアに委譲する。

### SA-06: 実行不可能な評価基準 - 無限範囲の検証 [severity: critical]
- 内容: Section 3 "Indexing & Performance" に「すべての可能なSQLクエリの実行計画を分析する」という実行不可能な基準が含まれている。
- 根拠: Line 40: "Analyze query execution plans for all possible SQL queries against the schema" - データモデル定義のみからは実際のクエリパターンは推測できず、"all possible queries" は組合せ爆発により評価不可能。
- 推奨: 基準を実行可能な形に修正する。例: "Analyze query execution plans for documented common access patterns" または "Verify indexes exist for foreign key and frequently queried columns"

### SA-07: 実行不可能な評価基準 - 運用データへの依存 [severity: critical]
- 内容: Section 5 "Audit & Compliance" に「本番環境の実際のクエリ実行時間を監視して性能目標を検証する」という、設計レビューの範囲を超えた基準が含まれている。
- 根拠: Line 53: "Monitor actual query execution times in production environment to verify performance targets" - これはデザインレビューではなく運用監視の責務であり、レビュー時点で実行不可能。
- 推奨: この基準を削除するか、デザインレビューの範囲に修正する。例: "Verify that performance targets are documented with measurable criteria (e.g., p95 latency < 100ms)"

### SA-08: 基準-ドメインカバレッジのギャップと過剰 [severity: improvement]
- 内容: データモデルレビューアの目的から期待されるドメイン領域と、実際の評価基準の間に不足と過剰が存在する。
- 根拠:
  - **ギャップ（不足）**:
    - データ型設計: 適切なデータ型選択（VARCHAR長、DECIMAL精度、日付型選択）に関する基準が不足
    - デッドロック対策: トランザクション設計やロック戦略に関する基準が不足
    - バックアップ・リカバリ: データ保護戦略に関する基準が不足
  - **過剰（スコープ外）**:
    - Section 6 "Distributed Systems": 分散システムの整合性は、データモデル設計よりもシステムアーキテクチャの領域
    - Scope "API response format validation": API設計は、データモデルとは別の専門領域
    - Scope "infrastructure capacity planning": インフラ計画は、データモデル設計の範囲を超える
  - **偏り**: Section 3 Performance に複数の基準が集中する一方、Section 1 Normalization には具体的な検証項目が不足（"properly normalized" の定義が曖昧）
- 推奨: (1) データ型設計、トランザクション安全性の基準を追加、(2) 分散システム、API、インフラ関連の基準を削除または別レビューアに移行、(3) 正規化基準を具体化（1NF/2NF/3NF/BCNF の明示的チェック項目）

### SA-09: 曖昧な評価基準 - 定義されていない標準 [severity: improvement]
- 内容: Section 3で "enterprise-grade database standards" への準拠を要求しているが、何が "enterprise-grade" かの定義がない。
- 根拠: Line 39: "Query performance should meet enterprise-grade database standards" - この標準は定義されておらず、レビューア間で解釈が異なる可能性がある。また、description (line 3) で "standards compliance" を謳っているが、どの標準（ISO、industry best practices、社内標準等）を指すのか不明。
- 推奨: 具体的な標準を定義する。例: "Query performance targets: p95 < 100ms for OLTP queries, < 5s for reporting queries" または参照する標準を明示（"Follow PostgreSQL Performance Best Practices", "Comply with ISO/IEC 11179 data definition standards"）

## Summary

- critical: 4
- improvement: 5
- info: 0
