# スコープ整合性分析 (Scope Alignment)

- agent_name: data-model-reviewer
- analyzed_at: 2026-02-12

## スコープ評価テーブル
| 観点 | 評価 | 判定 |
|------|------|------|
| スコープ定義品質 | EXPLICIT | 適切 |
| スコープ外文書化 | ABSENT | 問題あり |
| 境界明確性 | AMBIGUOUS | 要改善 |
| 内部整合性 | CONTRADICTORY | 問題あり |
| スコープ適切性 | TOO_BROAD | 要改善 |
| 基準-ドメインカバレッジ | BOTH | 問題あり |

## Findings

### SA-01: スコープ外領域の文書化が完全に欠如 [severity: improvement]
- 内容: Out-of-scope領域が全く文書化されていない。隣接する他のレビューアドメイン（セキュリティ、パフォーマンス、インフラ）との境界が不明確で、レビュー範囲の重複や漏れが発生しやすい。
- 根拠: エージェント定義全体に「Out-of-Scope」や「このレビューアが扱わない領域」に関する記述が一切存在しない。
- 推奨: 「Out-of-Scope」セクションを追加し、以下を明記する: (1) インフラレベルのDB設定・レプリケーション・バックアップ戦略は対象外（インフラレビューアの責務）、(2) SQLインジェクションなどのセキュリティ脆弱性は対象外（セキュリティレビューアの責務）、(3) アプリケーション実装レベルのロジックは対象外（コードレビューアの責務）

### SA-02: 隣接ドメインとの境界が曖昧（グレーゾーン未解決） [severity: improvement]
- 内容: "query performance optimization"（criteria 3）、"infrastructure capacity planning"（scope statement）、"monitor actual query execution times in production"（criteria 5）が、パフォーマンスレビューアやインフラレビューアのドメインと重複する可能性が高いが、責任分界点が不明確。
- 根拠: Evaluation Scopeに"infrastructure capacity planning"が含まれ、Criteria 3に"enterprise-grade database standards"、Criteria 5に"production environment monitoring"が含まれるが、これらは通常データモデルレビューの範囲を超える運用/インフラ領域。
- 推奨: 以下の境界ルールを明記する: (1) データモデルレビューアはスキーマレベルのインデックス設計とクエリ効率性（理論的パフォーマンス）を評価、(2) 実運用環境での計測・監視・キャパシティプランニングは対象外として、該当するレビューア（パフォーマンス/インフラ）にクロスリファレンスする。

### SA-03: 内部矛盾: Criteria 2でNOT NULL制約の相反する要求 [severity: critical]
- 内容: Criteria 2の最初の2つの記述が直接矛盾している。「All fields must have NOT NULL constraints」と「Optional fields should allow null values」は両立しない要件。
- 根拠:
  - Line 25: "All fields must have NOT NULL constraints to ensure data completeness."
  - Line 27: "Optional fields should allow null values to provide flexibility for partial data entry scenarios."
- 推奨: 以下のいずれかに修正: (1)「必須フィールドはNOT NULL制約を持つべき。オプショナルフィールドはNULL許容とする」（推奨）、(2) 削除して「NOT NULL制約の適切性を検証する」とシンプルにまとめる。

### SA-04: 内部矛盾: スコープ主張と実際の基準の不整合 [severity: improvement]
- 内容: Evaluation Scopeに"API response format validation"が明記されているが、対応する評価基準が存在しない。一方、Criteria 6（分散システムの参照整合性）はスコープ記述に含まれていない。
- 根拠:
  - Line 10: Evaluation Scopeに"API response format validation"が列挙されている
  - Criteria 1-6にAPI response formatに関する評価項目が一切ない
  - Line 59-64: Criteria 6（分散システム）の内容がスコープ記述に反映されていない
- 推奨: (1) API response format validationはデータモデルレビューの範囲外と判断できるため、スコープ記述から削除。該当するレビューア（API設計レビューア等）にクロスリファレンスする、(2) Criteria 6の分散システム整合性をスコープ記述に追加、または分散システム固有の評価は別レビューアに委譲する方針を明確化。

### SA-05: スコープが過剰に広範（TOO_BROAD） [severity: improvement]
- 内容: "infrastructure capacity planning"（キャパシティプランニング）、"monitor actual query execution times in production"（本番環境監視）、"distributed systems referential integrity"（分散DB整合性）は、データモデル設計レビューの範囲を大きく逸脱し、運用・インフラ・分散システムアーキテクチャの専門領域。
- 根拠:
  - Line 10: "infrastructure capacity planning"
  - Line 53: "Monitor actual query execution times in production environment"
  - Line 59-64: Criteria 6全体が分散システムの実装・運用レベルの要件
- 推奨: データモデルレビューのコア責務（正規化、整合性制約、スキーマ品質、インデックス設計の理論的評価）に焦点を絞る。キャパシティプランニング・本番監視・分散システム運用はスコープ外とし、対応するレビューア（インフラ/パフォーマンス/分散システムアーキテクト）への委譲を明記。

### SA-06: ドメインカバレッジギャップ: 目的記述から期待される領域に対応する基準が不足 [severity: improvement]
- 内容: エージェントの目的は「データモデル設計のnormalization, integrity, performance, standards compliance」だが、"standards compliance"に対応する明確な基準が不足している。また、"entity relationships"（ER図）の評価基準が形式的（Line 21: "documented with ER diagrams"）で、関係設計の品質（カーディナリティ、関係の適切性、循環参照等）を評価する基準がない。
- 根拠:
  - Line 3: description記述にstandards complianceが含まれる
  - Criteria 1-6に業界標準やベストプラクティスへの準拠を評価する具体的基準がない（naming conventionのみ）
  - Line 21: ER diagramの存在確認のみで、関係設計の妥当性評価が欠落
- 推奨: (1) Standards complianceの評価基準を追加（例: ISO/IEC 11179準拠、業界標準データモデルパターン適用の確認）、(2) Entity relationshipsの評価基準を拡充（カーディナリティの適切性、関係の正規化、循環参照の検証等）。

### SA-07: ドメインカバレッジ過剰: 目的外の基準が存在 [severity: improvement]
- 内容: Criteria 6（分散システムの参照整合性）は、エージェントの目的記述（データモデル設計のnormalization, integrity, performance, standards compliance）のいずれにも該当せず、分散システムアーキテクチャの専門領域。
- 根拠:
  - Line 3: 目的記述に分散システムの記述なし
  - Line 59-64: "Cross-shard references", "eventual consistency", "convergence time targets", "partition strategies"は分散DBアーキテクチャの実装戦略
- 推奨: Criteria 6を削除し、分散システム固有の整合性検証は別の専門レビューア（分散システムアーキテクト、インフラレビューア等）に委譲する。データモデルレビューアは単一データベースインスタンスのスキーマ品質に焦点を当てる。

### SA-08: 基準の実行可能性が曖昧（Criteria 3のクエリ分析） [severity: improvement]
- 内容: "Analyze query execution plans for all possible SQL queries against the schema"（Line 40）は実行不可能な要件。設計レビュー段階で「すべての可能なクエリ」を網羅的に分析することは現実的でない。
- 根拠: Line 40の記述は無限の可能性があるクエリすべてを要求しており、レビュー範囲が無制限に拡大するリスクがある。
- 推奨: 以下のいずれかに修正: (1)「代表的なアクセスパターン（CRUD、検索、レポート生成等）のクエリプランを分析」、(2)「想定される主要ユースケースのクエリ効率性を評価」とスコープを限定。

### SA-09: 基準の分布偏り: Integrityドメインに集中、他領域が手薄 [severity: info]
- 内容: Criteria 2（Data Integrity）とCriteria 4（Lifecycle）は詳細だが、Criteria 1（Normalization）は正規化技法の評価基準が抽象的で、実行可能な検証項目が少ない。また、performance領域（Criteria 3）も具体的なベンチマーク基準やSLO定義がない。
- 根拠:
  - Criteria 1 Line 16: "Properly normalized design should use proper normalization techniques"（循環定義で実行可能性が低い）
  - Criteria 2 Line 30-32: 具体的な制約種別（FK, Unique, Check）と検証項目が明確
  - Criteria 3 Line 39: "enterprise-grade database standards"が曖昧（定量基準なし）
- 推奨: (1) Criteria 1に正規化レベル（1NF/2NF/3NF/BCNF）の検証項目を追加、(2) Criteria 3にパフォーマンス目標の定量基準（例: 典型的クエリのレスポンス時間目標）を追加し、ドメイン間のバランスを改善。

## Summary

- critical: 1
- improvement: 7
- info: 1
