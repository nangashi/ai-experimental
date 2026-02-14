# Scope Alignment Analysis (Design Style)

- agent_name: data-model-reviewer
- analyzed_at: 2026-02-12

## Findings

### SA-DS-01: Scope statement contradicts actual criteria coverage [severity: critical]
- 内容: Scope statement claims to evaluate "API response format validation" and "infrastructure capacity planning" but no evaluation criteria address these areas
- 根拠: Line 10 lists "API response format validation, and infrastructure capacity planning" in the evaluation scope, but sections 1-6 contain no criteria for validating API response formats or planning infrastructure capacity
- 推奨: Either add criteria for these areas or remove them from the scope statement. If these are truly needed, create dedicated sections with specific evaluation points
- 検出戦略: Detection Strategy 1 (Scope Inventory) - mapping criteria to stated scope revealed coverage gaps

### SA-DS-02: Self-contradictory constraint requirements [severity: critical]
- 内容: Section 2 states mutually exclusive requirements for NULL constraints within the same paragraph
- 根拠: Line 25 states "All fields must have NOT NULL constraints to ensure data completeness" followed immediately by line 27 "Optional fields should allow null values to provide flexibility"
- 推奨: Clarify the rule: "Required fields must have NOT NULL constraints; optional fields should allow NULL values with proper default handling"
- 検出戦略: Detection Strategy 3 (Internal Consistency Verification) - identified logical contradiction in constraint rules

### SA-DS-03: Runtime monitoring claimed as design review responsibility [severity: critical]
- 内容: Section 5 includes "Monitor actual query execution times in production environment" as an evaluation criterion for data model design review
- 根拠: Line 53 instructs to "Monitor actual query execution times in production environment to verify performance targets" - this is runtime observability, not static design review
- 推奨: Remove production monitoring from this agent's scope. Data model reviewers should evaluate design choices that impact performance, not monitor runtime metrics. Defer to Observability/Monitoring agent
- 検出戦略: Detection Strategy 2 (Boundary Analysis - Overlap test) and Detection Strategy 4 (Adversarial Scope Testing - Territory grab)

### SA-DS-04: Distributed systems architecture outside data model scope [severity: improvement]
- 内容: Section 6 evaluates distributed system design decisions (sharding, partition strategies, eventual consistency) that extend beyond data model design into infrastructure architecture
- 根拠: Lines 60-64 require verification of "cross-shard references," "eventual consistency with convergence time targets," and "partition strategies" - these are distributed system architecture decisions
- 推奨: Limit scope to single-database data modeling. If distributed systems support is required, create explicit scope boundary: "For distributed systems, verify logical model correctness only; defer sharding strategy to Infrastructure agent"
- 検出戦略: Detection Strategy 1 (Scope Inventory) and Detection Strategy 4 (Adversarial Scope Testing - Territory grab)

### SA-DS-05: Deployment strategy outside data model review scope [severity: improvement]
- 内容: Section 4 evaluates migration deployment strategies ("expand-contract pattern for zero-downtime deployments") which belongs to DevOps/Deployment domain
- 根拠: Line 48 requires "Verifying migration strategies use expand-contract pattern for zero-downtime deployments" - this is deployment engineering, not data model design
- 推奨: Focus on migration script correctness (schema changes preserve data integrity) rather than deployment patterns. Defer zero-downtime deployment strategies to DevOps agent
- 検出戦略: Detection Strategy 2 (Boundary Analysis - Ownership test) and Detection Strategy 4 (Adversarial Scope Testing - Territory grab)

### SA-DS-06: Impossible evaluation requirement [severity: improvement]
- 内容: Section 3 requires "Analyze query execution plans for all possible SQL queries against the schema" which is computationally impossible for any non-trivial schema
- 根拠: Line 40 states "Analyze query execution plans for all possible SQL queries against the schema" - the set of all possible queries is infinite
- 推奨: Revise to "Analyze query execution plans for common query patterns documented in the design" or "Review index coverage for anticipated query workloads"
- 検出戦略: Detection Strategy 3 (Internal Consistency Verification) - identified infeasible criterion

### SA-DS-07: Missing out-of-scope documentation [severity: improvement]
- 内容: Agent definition lacks "Out of Scope" section to clarify boundaries with adjacent specialist agents
- 根拠: No explicit exclusions documented despite overlap potential with Security (sensitive data), Performance (query optimization), API Design (response formats), Infrastructure (capacity planning), and Observability (monitoring) agents
- 推奨: Add "Out of Scope" section: "This agent does NOT evaluate: runtime monitoring, security controls, API contracts, infrastructure sizing, or deployment pipelines. Defer to respective specialist agents"
- 検出戦略: Detection Strategy 2 (Boundary Analysis - missing documentation)

### SA-DS-08: Infrastructure capacity planning claimed without criteria [severity: improvement]
- 内容: Scope statement includes "infrastructure capacity planning" but no evaluation criteria address this domain
- 根拠: Line 10 claims scope includes "infrastructure capacity planning" but sections 1-6 contain no criteria for evaluating storage capacity, compute resources, or scaling requirements
- 推奨: Remove "infrastructure capacity planning" from scope. This is an Infrastructure/DevOps responsibility. Data model reviewer should focus on schema design efficiency, not infrastructure sizing
- 検出戦略: Detection Strategy 1 (Scope Inventory - coverage gaps) and Detection Strategy 4 (Adversarial Scope Testing - Stealth creep)

### SA-DS-09: Vague normalization criterion [severity: info]
- 内容: Section 1 states "Properly normalized design should use proper normalization techniques" which is circular and provides no actionable guidance
- 根拠: Line 16 contains tautological statement that doesn't specify which normal form (1NF, 2NF, 3NF, BCNF) or when denormalization is acceptable
- 推奨: Specify normalization requirements: "Schema should achieve 3NF minimum. Denormalization for read performance must be documented with justification"
- 検出戦略: Detection Strategy 3 (Internal Consistency Verification) - identified non-actionable criterion

### SA-DS-10: Redundant index verification instruction [severity: info]
- 内容: Section 3 header and bullet point duplicate the same instruction about index coverage
- 根拠: Line 35 states "Check index design and coverage for all tables" and line 36 immediately repeats "evaluate database indexing strategy to ensure query performance"
- 推奨: Consolidate into single clear instruction: "Verify index coverage supports common query patterns with appropriate composite index design"
- 検出戦略: Detection Strategy 3 (Internal Consistency Verification) - identified redundancy

## Summary

- critical: 3
- improvement: 5
- info: 2
