# 基準有効性分析 (Criteria Effectiveness)

- agent_name: data-model-reviewer
- analyzed_at: 2026-02-12

## 基準別評価テーブル
| 基準 | S/N比 | 実行可能性 | 費用対効果 | 判定 |
|------|-------|-----------|-----------|------|
| Normalization & Structure - "Properly normalized design" | L | D | L | 要改善 |
| Normalization & Structure - Table naming conventions | H | E | H | 有効 |
| Normalization & Structure - Primary keys definition | H | E | H | 有効 |
| Normalization & Structure - ER diagram documentation | M | E | M | 有効 |
| Data Integrity - NOT NULL constraint rule | L | D | M | 要改善 |
| Data Integrity - Optional fields null allowance | L | D | M | 要改善 |
| Data Integrity - Foreign key cascade rules | H | E | M | 有効 |
| Data Integrity - Unique constraints | H | E | M | 有効 |
| Data Integrity - Check constraints | M | E | M | 有効 |
| Indexing & Performance - "Check index design and coverage for all tables" | L | D | L | 要改善 |
| Indexing & Performance - "Enterprise-grade database standards" | L | D | L | 要改善 |
| Indexing & Performance - "Analyze query execution plans for all possible SQL queries" | L | I | L | 逆効果の可能性 |
| Indexing & Performance - Primary/foreign key indexes | H | E | H | 有効 |
| Indexing & Performance - Composite index left-prefix rule | H | E | H | 有効 |
| Data Lifecycle - Retention policies with explicit durations | H | E | M | 有効 |
| Data Lifecycle - Expand-contract migration pattern | H | E | M | 有効 |
| Data Lifecycle - "Aligning with the existing data dictionary" | M | D | M | 有効 |
| Audit & Compliance - "Look for any data modeling concerns that may affect compliance" | L | D | L | 要改善 |
| Audit & Compliance - "Monitor actual query execution times in production environment" | L | I | L | 逆効果の可能性 |
| Audit & Compliance - Audit columns requirement | H | E | H | 有効 |
| Audit & Compliance - Soft delete pattern | H | E | H | 有効 |
| Referential Integrity in Distributed Systems - Cross-shard verification | M | I | L | 逆効果の可能性 |
| Referential Integrity in Distributed Systems - Application-level consistency checks | M | E | M | 有効 |
| Referential Integrity in Distributed Systems - Eventual consistency documentation | H | E | M | 有効 |
| Referential Integrity in Distributed Systems - Partition strategy appropriateness | M | D | M | 有効 |

## Findings

### CE-01: Tautological criterion "Properly normalized design should use proper normalization techniques" [severity: improvement]
- 内容: Section 1 contains the statement "Properly normalized design should use proper normalization techniques" which restates the section title without providing operational guidance.
- 根拠: Tautology Detection: The criterion defines "properly normalized" using "proper normalization" creating a circular definition. Actionability Test: Cannot be converted to a procedural checklist without external normalization rule definitions (1NF/2NF/3NF/BCNF).
- 推奨: Replace with mechanically checkable criteria such as: "Verify no repeating groups in single columns (1NF)", "Verify all non-key attributes depend on entire primary key (2NF)", "Verify no transitive dependencies exist (3NF)".
- 運用特性: S/N=L, 実行可能性=D, 費用対効果=L

### CE-02: Contradictory NOT NULL constraint rules [severity: critical]
- 内容: Section 2 contains contradictory statements: "All fields must have NOT NULL constraints to ensure data completeness" immediately followed by "Optional fields should allow null values to provide flexibility for partial data entry scenarios."
- 根拠: Contradiction Check: These two directives prescribe mutually exclusive actions. The first mandates NOT NULL on all fields; the second mandates allowing NULL on some fields. An agent cannot simultaneously satisfy both.
- 推奨: Clarify with a single coherent rule such as: "Required business fields must have NOT NULL constraints. Optional fields should allow NULL. Define field optionality based on business requirements documented in data dictionary."
- 運用特性: S/N=L, 実行可能性=D, 費用対効果=M

### CE-03: Vague "enterprise-grade database standards" without definition [severity: improvement]
- 内容: Section 3 states "Query performance should meet enterprise-grade database standards" without defining measurable thresholds.
- 根拠: Pseudo-Precision Detection: Uses precise-sounding language ("enterprise-grade") but lacks measurability. Actionability Test: Cannot be converted to a procedural checklist without specific latency/throughput targets (e.g., "SELECT queries <100ms at p95").
- 推奨: Replace with concrete thresholds: "Single-record SELECT queries must complete in <50ms at p95. Range queries returning ≤100 rows must complete in <200ms at p95. Define thresholds for each query type in performance requirements."
- 運用特性: S/N=L, 実行可能性=D, 費用対効果=L

### CE-04: Infeasible "analyze query execution plans for all possible SQL queries" [severity: critical]
- 内容: Section 3 requires "Analyze query execution plans for all possible SQL queries against the schema."
- 根拠: Executability Detection: INFEASIBLE. The set of "all possible SQL queries" is infinite (combinatorial explosion of WHERE clauses, JOINs, subqueries). Even constraining to "realistic" queries requires executing database EXPLAIN commands, which is unavailable in static file review context. Cost Detection: Would require >10 file operations plus database access, exceeding LOW cost-effectiveness threshold.
- 推奨: Replace with mechanically checkable static criteria: "Verify indexes exist for all foreign key columns. Verify composite indexes exist for columns frequently queried together (as documented in query catalog). Document expected query patterns and verify covering indexes exist."
- 運用特性: S/N=L, 実行可能性=I, 費用対効果=L

### CE-05: Vague "check index design and coverage for all tables" [severity: improvement]
- 内容: Section 3 states "Check index design and coverage for all tables" without defining what constitutes adequate coverage.
- 根拠: Vague Expression Detection: "coverage" is context-dependent and undefined. Actionability Test: Without coverage thresholds (e.g., "90% of documented query patterns have covering indexes"), cannot create deterministic checklist. Duplication Check: This criterion has >70% semantic overlap with later specific index criteria (primary/foreign key indexes, composite indexes).
- 推奨: Delete this redundant high-level criterion and rely on specific mechanically checkable index criteria already present: primary/foreign key indexing, composite index left-prefix rule.
- 運用特性: S/N=L, 実行可能性=D, 費用対効果=L

### CE-06: Infeasible "Monitor actual query execution times in production environment" [severity: critical]
- 内容: Section 5 requires "Monitor actual query execution times in production environment to verify performance targets."
- 根拠: Executability Detection: INFEASIBLE. Static file review of data model designs cannot access runtime production monitoring data. This criterion requires observability tooling (APM, database metrics) unavailable during design review phase.
- 推奨: Remove this criterion from design review agent. Runtime performance monitoring belongs to operational observability, not static design review. Design review should verify static performance-enabling factors (indexes, query patterns documentation, denormalization justification).
- 運用特性: S/N=L, 実行可能性=I, 費用対効果=L

### CE-07: Vague "Look for any data modeling concerns that may affect compliance" [severity: improvement]
- 内容: Section 5 states "Look for any data modeling concerns that may affect compliance" without defining specific compliance requirements or detection criteria.
- 根拠: Vague Expression Detection: "any concerns" and "may affect" create unbounded ambiguity. Actionability Test: Cannot convert to procedural checklist without enumerating specific compliance requirements (GDPR personal data flags, HIPAA audit trails, SOX financial data retention). Signal-to-Noise: HIGH false positive risk due to broad interpretation variance.
- 推奨: Replace with specific mechanically checkable compliance criteria: "Verify PII fields are flagged for encryption-at-rest. Verify audit columns exist on financial transaction tables. Verify retention policies align with regulatory requirements (reference compliance matrix)."
- 運用特性: S/N=L, 実行可能性=D, 費用対効果=L

### CE-08: Infeasible "Verify referential integrity across all distributed database shards" [severity: critical]
- 内容: Section 6 requires "Verify referential integrity across all distributed database shards."
- 根拠: Executability Detection: INFEASIBLE for static design review. Verifying cross-shard referential integrity requires: (1) Runtime shard topology knowledge (2) Distributed transaction tracing or consistency checker execution. Cost Detection: Would require >10 file operations plus distributed system runtime access, exceeding LOW cost-effectiveness threshold. This is a runtime verification task, not design review task.
- 推奨: Replace with static design criteria: "Verify cross-shard references are documented with explicit consistency model (strong/eventual). Verify application-level consistency check logic is specified for eventual consistency scenarios. Document shard partition key strategy and cross-shard query patterns."
- 運用特性: S/N=M, 実行可能性=I, 費用対効果=L

### CE-09: Undefined "data dictionary" reference without location [severity: info]
- 内容: Section 4 mentions "Aligning with the existing data dictionary" without specifying where this data dictionary exists or how to access it.
- 根拠: Actionability Test: Agent cannot mechanically verify alignment without knowing data dictionary file path or access method. However, criterion intent is clear and has moderate S/N ratio if data dictionary location is provided in agent context.
- 推奨: Add to agent instructions: "Data dictionary location: {path}. Cross-reference field optionality, naming conventions, and business rules against data dictionary definitions."
- 運用特性: S/N=M, 実行可能性=D, 費用対効果=M

### CE-10: Redundant "Ensure data model quality is maintained across all entities" [severity: info]
- 内容: Section 1 opening statement "Ensure data model quality is maintained across all entities" is redundant with more specific criteria.
- 根拠: Duplication Check: This high-level statement has >70% semantic overlap with all subsequent specific criteria (normalization, naming, keys, relationships). Signal-to-Noise: Adds no actionable guidance beyond what specific criteria provide.
- 推奨: Delete redundant introductory statement. Specific criteria are sufficient. Alternatively, rephrase as scope definition: "This section evaluates structural aspects of entity design including normalization, naming, and relationship documentation."
- 運用特性: S/N=M, 実行可能性=E, 費用対効果=M

## Summary

- critical: 4
- improvement: 5
- info: 2
