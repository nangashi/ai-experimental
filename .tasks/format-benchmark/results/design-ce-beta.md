# Criteria Effectiveness Analysis (Design Style)

- agent_name: data-model-reviewer
- analyzed_at: 2026-02-12

## Findings

### CE-DS-01: Tautological criterion provides no operational guidance [severity: critical]
- 内容: Criterion defines normalization using the same term being defined, creating a circular reference with zero actionable guidance.
- 根拠: "Properly normalized design should use proper normalization techniques."
- 推奨: Replace with specific, checkable rules: "Tables are in 3NF or higher: (1) No repeating groups, (2) No partial key dependencies, (3) No transitive dependencies. Check each table for violations of these three rules."
- 検出戦略: Detection Strategy 2 (Tautology test), Detection Strategy 5 (Structural Antipatterns - Tautology)

### CE-DS-02: Contradictory NOT NULL requirements [severity: critical]
- 内容: Two criteria within the same section prescribe mutually exclusive actions, making it impossible to satisfy both.
- 根拠: "All fields must have NOT NULL constraints to ensure data completeness." followed immediately by "Optional fields should allow null values to provide flexibility for partial data entry scenarios."
- 推奨: Replace with: "Mandatory fields (required for business logic) must have NOT NULL constraints. Optional fields (not required for business logic) must allow NULL values. Document the business rationale for each field's nullability."
- 検出戦略: Detection Strategy 2 (Contradiction test), Detection Strategy 4 (Cross-Criteria Consistency - Contradiction)

### CE-DS-03: Infeasible exhaustive query analysis requirement [severity: critical]
- 内容: Requires analyzing an infinite set ("all possible SQL queries"), which is mathematically impossible and would never terminate.
- 根拠: "Analyze query execution plans for all possible SQL queries against the schema"
- 推奨: Replace with: "Analyze query execution plans for the 5-10 most frequent query patterns identified in the design document. For each query: (1) Check if indexes support the WHERE/JOIN columns, (2) Verify no full table scans on large tables, (3) Confirm join order is optimized."
- 検出戦略: Detection Strategy 3 (Operational Feasibility - infinite set), Detection Strategy 5 (Feasibility Antipatterns - Exhaustive enumeration)

### CE-DS-04: Runtime monitoring in static review context [severity: critical]
- 内容: Requires production runtime data that is unavailable during static design review.
- 根拠: "Monitor actual query execution times in production environment to verify performance targets."
- 推奨: Remove this criterion entirely. Static design reviews cannot access production monitoring data. If performance verification is needed, create a separate post-deployment review process.
- 検出戦略: Detection Strategy 3 (Tool requirements - runtime monitoring unavailable), Detection Strategy 5 (Feasibility Antipatterns - Runtime observation)

### CE-DS-05: Distributed shard verification exceeds agent scope [severity: critical]
- 内容: Requires cross-system distributed database access that exceeds single-agent capability and is infeasible in static review.
- 根拠: "Verify referential integrity across all distributed database shards."
- 推奨: Replace with: "For designs specifying distributed sharding: (1) Check that cross-shard references are documented, (2) Verify application-level consistency mechanism is specified (e.g., saga pattern, two-phase commit), (3) Confirm shard key selection is documented with rationale."
- 検出戦略: Detection Strategy 3 (Tool requirements - cross-system access unavailable), Detection Strategy 5 (Efficiency Antipatterns - Cross-system analysis)

### CE-DS-06: Undefined external standard reference [severity: critical]
- 内容: References "enterprise-grade database standards" without defining what this means, enabling agents to claim compliance arbitrarily.
- 根拠: "Query performance should meet enterprise-grade database standards"
- 推奨: Replace with specific thresholds: "For tables >10K rows: (1) Indexed queries complete in <100ms, (2) JOIN operations use indexes on both sides, (3) No queries scan >10% of table rows unless explicitly justified in design doc."
- 検出戦略: Detection Strategy 2 (Pseudo-precision test), Detection Strategy 5 (Vagueness Antipatterns - External standards without version)

### CE-DS-07: Missing reference to "existing data dictionary" [severity: critical]
- 内容: Criterion requires alignment with an external document but provides no path, making verification impossible.
- 根拠: "Aligning with the existing data dictionary"
- 推奨: Either (1) remove this criterion, or (2) replace with: "Check alignment with data dictionary at {specific_file_path}. Verify: (1) Column names match dictionary naming conventions, (2) Data types are consistent with dictionary definitions, (3) New entities are documented."
- 検出戦略: Detection Strategy 3 (Context requirements - location unspecified), Detection Strategy 5 (Feasibility Antipatterns - References without location)

### CE-DS-08: Aspirational compliance check without detection method [severity: critical]
- 内容: Asks to "look for concerns" without providing any method to detect them, making output arbitrary.
- 根拠: "Look for any data modeling concerns that may affect compliance."
- 推奨: Replace with specific compliance checks: "For regulated data (PII, financial, health): (1) Check encryption-at-rest specification exists, (2) Verify data retention policy matches regulatory requirements (GDPR 30 days for deletion requests, SOX 7 years for financial records), (3) Confirm access control model is documented."
- 検出戦略: Detection Strategy 1 (Aspirational classification), Detection Strategy 2 (Evasion test), Detection Strategy 5 (Structural Antipatterns - Aspirational)

### CE-DS-09: Duplicate indexing criteria reduce signal-to-noise ratio [severity: improvement]
- 内容: Two criteria within the same section have >70% semantic overlap, creating redundancy without adding value.
- 根拠: "Check index design and coverage for all tables. Additionally, evaluate database indexing strategy to ensure query performance."
- 推奨: Consolidate into single criterion: "For each table: (1) Verify primary key has clustered index, (2) Check foreign key columns have indexes, (3) Confirm composite indexes follow left-prefix rule for multi-column queries, (4) Validate WHERE clause columns in frequent queries are indexed."
- 検出戦略: Detection Strategy 4 (Cross-Criteria Consistency - Duplication)

### CE-DS-10: Vague "natural key candidates" lacks definition [severity: improvement]
- 内容: Uses undefined domain term "natural key candidates" without providing detection criteria.
- 根拠: "Unique constraints are applied to natural key candidates"
- 推奨: Replace with: "Unique constraints are applied to natural keys (business-meaningful identifiers like email, SSN, order_number). For each entity, verify: (1) Natural key columns are identified, (2) UNIQUE constraint exists, (3) Rationale for choosing natural vs. surrogate key is documented."
- 検出戦略: Detection Strategy 5 (Vagueness Antipatterns - undefined terms)

### CE-DS-11: Undefined "appropriate" partition strategies [severity: improvement]
- 内容: Uses vague qualifier "appropriate" without defining evaluation criteria.
- 根拠: "Partition strategies are appropriate for data access patterns"
- 推奨: Replace with: "For partitioned tables: (1) Partition key matches the most common WHERE clause predicate (e.g., date ranges for time-series data), (2) Partition size stays under 100GB, (3) Design document justifies partition strategy with access pattern analysis."
- 検出戦略: Detection Strategy 5 (Vagueness Antipatterns - "appropriate" without threshold)

### CE-DS-12: Scope-criteria mismatch for API response format and capacity planning [severity: improvement]
- 内容: Evaluation scope promises coverage of "API response format validation" and "infrastructure capacity planning" but no criteria address these areas.
- 根拠: Scope states "API response format validation, and infrastructure capacity planning" but no criteria in sections 1-6 cover these topics.
- 推奨: Either (1) remove these from scope, or (2) add criteria: "API Response Format: (1) Check JSON schema is defined for all endpoints, (2) Verify response field names match database column naming conventions, (3) Confirm pagination parameters are specified for list endpoints. Capacity Planning: (1) Verify expected data volume is documented (rows/year), (2) Check storage growth projections exist, (3) Confirm index size estimates are provided."
- 検出戦略: Detection Strategy 4 (Cross-Criteria Consistency - Gap)

### CE-DS-13: Missing scope boundaries for query complexity [severity: info]
- 内容: Criterion 3.6 "composite indexes follow left-prefix rule" is effective but could benefit from specifying when to stop checking (e.g., max index columns).
- 根拠: "Composite indexes follow left-prefix rule for multi-column queries"
- 推奨: Add boundary: "For composite indexes up to 4 columns (indexes >4 columns require explicit justification): verify query predicates match index column order from left to right."
- 検出戦略: Detection Strategy 3 (Decision complexity)

## Summary

- critical: 8
- improvement: 4
- info: 1
