# Scope Alignment Analysis (Design Style)

- agent_name: data-model-reviewer
- analyzed_at: 2026-02-12

## Findings

### SA-DS-01: Missing Scope Definition Section [severity: critical]
- 内容: The agent definition lacks a clear "Scope" section that explicitly states what is IN scope vs OUT of scope. The "Evaluation Scope" section is actually a list of criteria, not a scope boundary definition.
- 根拠: No dedicated section defining scope boundaries; "Evaluation Scope" section lists topics without clarifying boundaries with adjacent domains
- 推奨: Add explicit "In Scope" and "Out of Scope" sections. Define what constitutes "data model design" vs adjacent domains (API design, infrastructure, operations, distributed systems architecture).
- 検出戦略: Detection Strategy 2 (Boundary Analysis - Missing documentation)

### SA-DS-02: Self-Contradictory Constraint Requirements [severity: critical]
- 内容: Criterion 2 contains a direct logical contradiction: "All fields must have NOT NULL constraints" is immediately followed by "Optional fields should allow null values"
- 根拠: Lines 25-27 of the definition contain contradictory requirements
- 推奨: Clarify the constraint policy: either specify which field types require NOT NULL, or explain the decision criteria for nullable vs non-nullable fields
- 検出戦略: Detection Strategy 3 (Internal Consistency Verification)

### SA-DS-03: Scope Creep into Infrastructure Domain [severity: critical]
- 内容: The stated scope includes "infrastructure capacity planning" but (1) no corresponding criteria exist and (2) this belongs to infrastructure/SRE agents, not data model design
- 根拠: "infrastructure capacity planning" appears in line 10 of Evaluation Scope section; no infrastructure criteria in sections 1-6
- 推奨: Remove "infrastructure capacity planning" from scope or clarify it means "schema design considerations for infrastructure" with explicit boundaries
- 検出戦略: Detection Strategy 1 (Scope Inventory - coverage gaps) + Detection Strategy 4 (Adversarial Scope Testing - territory grab)

### SA-DS-04: Scope Creep into API Design Domain [severity: critical]
- 内容: The stated scope includes "API response format validation" but (1) no corresponding criteria exist and (2) this belongs to API design agents, not database schema design
- 根拠: "API response format validation" appears in line 10; no API criteria in sections 1-6
- 推奨: Remove "API response format validation" from scope or move it to a separate API design reviewer agent
- 検出戦略: Detection Strategy 1 (Scope Inventory - coverage gaps) + Detection Strategy 4 (Adversarial Scope Testing - territory grab)

### SA-DS-05: Operational Monitoring Masquerading as Design Review [severity: critical]
- 内容: Criterion 5 requires "Monitor actual query execution times in production environment" - this is runtime operations monitoring, not design review
- 根拠: Line 53 explicitly states "Monitor actual query execution times in production environment"
- 推奨: Remove production monitoring from criteria. If query performance is in scope, limit to design-time analysis (e.g., "Verify indexes exist for expected query patterns")
- 検出戦略: Detection Strategy 3 (Internal Consistency Verification) + Detection Strategy 4 (Adversarial Scope Testing - stealth creep)

### SA-DS-06: Impossible Criterion - Exhaustive Query Analysis [severity: critical]
- 内容: Criterion 3 requires "Analyze query execution plans for all possible SQL queries against the schema" - mathematically impossible and not achievable in design review
- 根拠: Line 40 contains this requirement
- 推奨: Change to "Analyze query execution plans for documented/expected query patterns" or "Verify indexes support the primary access patterns documented in the design"
- 検出戦略: Detection Strategy 3 (Internal Consistency Verification)

### SA-DS-07: Deployment Strategy Scope Creep [severity: improvement]
- 内容: Criterion 4 extends from data lifecycle into deployment operations: "migration strategies use expand-contract pattern for zero-downtime deployments"
- 根拠: Line 48 includes deployment strategy requirements
- 推奨: Clarify boundary: data model reviewer checks schema versioning compatibility, but deployment strategy belongs to DevOps agents. Add handoff protocol.
- 検出戦略: Detection Strategy 1 (Scope Inventory - scope creep) + Detection Strategy 4 (Adversarial Scope Testing - stealth creep)

### SA-DS-08: Distributed Systems Architecture Scope Creep [severity: improvement]
- 内容: Criterion 6 extends from data modeling into distributed systems architecture: sharding strategies, cross-shard consistency, partition strategies
- 根拠: Lines 59-64 cover distributed systems concerns
- 推奨: Clarify boundary: if distributed systems are in scope, make this explicit in scope statement and define handoff to distributed systems architects for system-level design
- 検出戦略: Detection Strategy 1 (Scope Inventory - scope creep) + Detection Strategy 4 (Adversarial Scope Testing - territory grab)

### SA-DS-09: Ambiguous "Compliance" Without Domain Specification [severity: improvement]
- 内容: Criterion 5 states "Look for any data modeling concerns that may affect compliance" without specifying which compliance domains (GDPR, SOC2, HIPAA, etc.)
- 根拠: Line 52 mentions compliance without boundaries
- 推奨: Either specify compliance domains in scope or clarify that compliance is owned by dedicated compliance/security agents and provide handoff protocol
- 検出戦略: Detection Strategy 2 (Boundary Analysis - ownership test)

### SA-DS-10: Vacuous Normalization Criterion [severity: improvement]
- 内容: Criterion 1 states "Ensure data model quality is maintained" and "should use proper normalization techniques" - these are circular/vacuous statements that don't specify what to check
- 根拠: Lines 16-17 contain non-specific requirements
- 推奨: Specify concrete normalization requirements (e.g., "Verify 3NF for transactional tables", "Check for denormalization justification in read-heavy scenarios")
- 検出戦略: Detection Strategy 3 (Internal Consistency Verification)

### SA-DS-11: Missing Cross-Agent References [severity: improvement]
- 内容: No cross-references to adjacent agents for overlapping concerns (security for access control, performance for load testing, API design for response formats)
- 根拠: Absence of cross-references throughout the definition
- 推奨: Add "Related Agents" section listing adjacent agents and handoff protocols for boundary cases
- 検出戦略: Detection Strategy 2 (Boundary Analysis - missing cross-references)

### SA-DS-12: Unclear Query Performance Boundary [severity: improvement]
- 内容: "Query performance optimization" appears in scope but it's unclear if this is design-time analysis or runtime testing - creates overlap with performance testing agents
- 根拠: Line 10 includes "query performance optimization"; line 40-41 mention execution plan analysis; line 53 mentions production monitoring
- 推奨: Clarify boundary: data model reviewer checks index coverage for documented queries; performance testing agent owns load testing and production monitoring
- 検出戦略: Detection Strategy 2 (Boundary Analysis - gray zones)

### SA-DS-13: "Enterprise-Grade" Undefined Standard [severity: info]
- 内容: Criterion 3 requires "Query performance should meet enterprise-grade database standards" without defining what "enterprise-grade" means
- 根拠: Line 39 contains undefined standard
- 推奨: Either remove subjective term or define concrete metrics (e.g., "queries complete within 100ms for 95th percentile")
- 検出戦略: Detection Strategy 3 (Internal Consistency Verification)

### SA-DS-14: Data Dictionary Reference Without Context [severity: info]
- 内容: Criterion 4 mentions "Aligning with the existing data dictionary" but doesn't clarify if this is a scope boundary or a verification step
- 根拠: Line 49 references data dictionary without context
- 推奨: Clarify: is the data dictionary in scope for review, or is it an external reference that this agent must align with?
- 検出戦略: Detection Strategy 2 (Boundary Analysis - handoff test)

## Summary

- critical: 6
- improvement: 6
- info: 2
