# 基準有効性分析 (Criteria Effectiveness)

- agent_name: data-model-reviewer
- analyzed_at: 2026-02-12

## 基準別評価テーブル
| 基準 | S/N比 | 実行可能性 | 費用対効果 | 判定 |
|------|-------|-----------|-----------|------|
| Normalization & Structure | M | D | M | 要改善 |
| Data Integrity Constraints | L | I | L | 逆効果の可能性 |
| Indexing & Performance | L | I | L | 逆効果の可能性 |
| Data Lifecycle & Migration | M | D | M | 要改善 |
| Audit & Compliance | L | I | L | 逆効果の可能性 |
| Referential Integrity in Distributed Systems | L | I | L | 逆効果の可能性 |

## Findings

### CE-01: Tautological normalization instruction [severity: critical]
- 内容: Criterion 1 states "Ensure data model quality is maintained across all entities. Properly normalized design should use proper normalization techniques." This is circular definition without operational guidance.
- 根拠: The instruction restates "proper normalization" using "proper normalization techniques" without defining what constitutes proper normalization (1NF/2NF/3NF/BCNF), when to denormalize, or how to detect violations. Fails Tautology Detection check.
- 推奨: Replace with mechanically checkable criteria: "Verify all tables are in 3NF: (1) Each non-key column depends only on the full primary key, (2) No transitive dependencies exist, (3) Document any intentional denormalization with performance justification."
- 運用特性: S/N=L, 実行可能性=D, 費用対効果=M

### CE-02: Contradictory NOT NULL constraint requirements [severity: critical]
- 内容: Criterion 2 states "All fields must have NOT NULL constraints" immediately followed by "Optional fields should allow null values". These are mutually exclusive instructions.
- 根拠: Fails Contradiction Check. An agent cannot simultaneously apply NOT NULL to all fields and allow null values for optional fields. The criterion provides no decision procedure for determining which rule takes precedence.
- 推奨: Replace with consistent rule: "Apply NOT NULL constraints to mandatory business fields (e.g., user_id, created_at). Document optional fields with explicit business justification for allowing NULL."
- 運用特性: S/N=L, 実行可能性=I, 費用対効果=L

### CE-03: Infeasible query execution plan analysis [severity: critical]
- 内容: Criterion 3 requires "Analyze query execution plans for all possible SQL queries against the schema" and "Query performance should meet enterprise-grade database standards".
- 根拠: Fails Executability Detection Procedure. (1) Requires executing EXPLAIN ANALYZE on a live database system (tool unavailable), (2) "All possible SQL queries" is combinatorially explosive for schemas with >5 tables, (3) "Enterprise-grade standards" is undefined (Pseudo-Precision). Marked as INFEASIBLE.
- 推奨: Replace with static analysis: "Verify indexes exist for: (1) All foreign key columns, (2) Columns used in WHERE clauses of documented query patterns, (3) Columns in ORDER BY clauses of paginated queries."
- 運用特性: S/N=L, 実行可能性=I, 費用対効果=L

### CE-04: Infeasible production monitoring requirement [severity: critical]
- 内容: Criterion 5 states "Monitor actual query execution times in production environment to verify performance targets".
- 根拠: Fails Executability Check. Requires access to production monitoring systems and runtime query logs (tools unavailable). This is a runtime operational concern, not a static design review criterion. Marked as INFEASIBLE.
- 推奨: Delete this criterion. Runtime monitoring is not executable during design review phase. If performance validation is critical, replace with: "Verify design document includes performance targets (e.g., p95 <100ms) and documents expected query patterns."
- 運用特性: S/N=L, 実行可能性=I, 費用対効果=L

### CE-05: Infeasible distributed system verification [severity: critical]
- 内容: Criterion 6 requires "Verify referential integrity across all distributed database shards" and "Ensure eventual consistency with convergence time targets".
- 根拠: Fails Executability Check. (1) Requires runtime observation of distributed system behavior across shards (tool unavailable), (2) Convergence time measurement requires executing distributed transactions and timing reconciliation (infeasible statically), (3) "Application-level consistency checks" cannot be verified without executing application code. Marked as INFEASIBLE.
- 推奨: Replace with static documentation checks: "Verify design document: (1) Explicitly identifies cross-shard references, (2) Documents compensation strategies for failed distributed transactions, (3) Specifies partition key for each table."
- 運用特性: S/N=L, 実行可能性=I, 費用対効果=L

### CE-06: Vague "data modeling concerns" criterion [severity: improvement]
- 内容: Criterion 5 states "Look for any data modeling concerns that may affect compliance" without defining what constitutes a "concern" or which compliance standards apply.
- 根拠: Fails Vague Expression Detection (contains "any...concerns") and Context-Dependent Vagueness (compliance requirements are high-precision contexts). Cannot be converted to procedural checklist (fails Actionability Test).
- 推奨: Replace with explicit compliance checklist: "Verify compliance requirements: (1) PII fields are documented with encryption requirements, (2) GDPR right-to-erasure is supported via soft delete or data retention policies, (3) Audit trail captures data access events."
- 運用特性: S/N=L, 実行可能性=D, 費用対効果=M

### CE-07: Duplicate indexing criteria [severity: improvement]
- 内容: Criterion 3 contains both "Check index design and coverage for all tables" and "Evaluate database indexing strategy to ensure query performance". These overlap >70% semantically.
- 根拠: Fails Duplication Check. Both phrases instruct checking indexes for performance, creating redundant verification without additional operational guidance.
- 推奨: Consolidate into single criterion: "Verify indexing strategy: (1) Primary and foreign keys have indexes, (2) Composite indexes follow left-prefix rule, (3) Documented query patterns have supporting indexes."
- 運用特性: S/N=M, 実行可能性=D, 費用対効果=M

### CE-08: Ambiguous "appropriate" and "proper" usage [severity: improvement]
- 内容: Multiple criteria use vague qualifiers: "appropriate" (partition strategies), "proper" (normalization, primary keys), without defining selection criteria.
- 根拠: Fails Vague Expression Detection. These terms appear in contexts requiring precision (partitioning strategy selection, normalization level choice) but provide no decision framework.
- 推奨: Replace with decision criteria: (1) "Partition strategies: Use hash partitioning for uniform distribution, range partitioning for time-series data", (2) "Primary key selection: Use auto-increment for single-node DBs, UUID v7 for distributed systems."
- 運用特性: S/N=M, 実行可能性=D, 費用対効果=M

### CE-09: Undefined ER diagram verification [severity: info]
- 内容: Criterion 1 requires "Relationships are documented with ER diagrams" but does not specify verification procedure.
- 根拠: Passes basic executability (can check for diagram file existence) but lacks specificity on diagram completeness or notation standards (UML? Chen? Crow's foot?).
- 推奨: Add verification detail: "ER diagram exists in /docs/data-model/ using Crow's foot notation, includes all entities, shows cardinality (1:1, 1:N, N:M), and documents cascade delete behavior."
- 運用特性: S/N=M, 実行可能性=E, 費用対効果=H

### CE-10: Cascade rule verification is executable [severity: info]
- 内容: Criterion 2 requires "Foreign key constraints are defined with explicit cascade rules (CASCADE/SET NULL/RESTRICT)".
- 根拠: Passes all checks: (1) Clear enumeration of acceptable values, (2) Mechanically checkable via schema file parsing (Read + pattern matching), (3) Low cost (≤3 file reads). This is an effective criterion.
- 推奨: No changes needed. Consider documenting expected locations of schema files to further reduce cost (e.g., "Check files matching db/migrations/*.sql").
- 運用特性: S/N=H, 実行可能性=E, 費用対効果=H

### CE-11: Check constraint examples are specific [severity: info]
- 内容: Criterion 2 provides concrete examples: "Check constraints validate business rules (e.g., positive amounts, valid date ranges)".
- 根拠: Passes Actionability Test (can be converted to procedural checklist) and Executability Check (statically verifiable via schema parsing). Examples reduce ambiguity.
- 推奨: Minor enhancement: Add verification procedure: "Use Grep to search schema files for CHECK constraint definitions, verify constraints exist for amount fields (>= 0) and date columns (end_date > start_date)."
- 運用特性: S/N=H, 実行可能性=E, 費用対効果=H

### CE-12: Audit columns requirement is clear [severity: info]
- 内容: Criterion 5 requires "Audit columns (created_at, updated_at, created_by) exist on all mutable tables".
- 根拠: Passes all checks: (1) Explicit column name enumeration removes ambiguity, (2) "Mutable tables" has clear definition (tables with UPDATE operations), (3) Mechanically checkable via schema parsing. High S/N ratio.
- 推奨: Add minor clarification: "Define mutable tables as 'tables without IMMUTABLE constraint or append-only documentation'. Check schema files for timestamp and user tracking columns."
- 運用特性: S/N=H, 実行可能性=E, 費用対効果=H

## Summary

- critical: 5
- improvement: 3
- info: 4
