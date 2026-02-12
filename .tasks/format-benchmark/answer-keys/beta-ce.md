# Answer Key: beta CE (Criteria Effectiveness)

10 planted problems in data-model-reviewer.

| ID | Type | Section | Problematic Text | Why It's a Problem |
|----|------|---------|-------------------|-------------------|
| Q1 | vague | §1 para 1 | "Ensure data model quality is maintained across all entities" | No definition of "quality"; unactionable aspirational statement |
| Q2 | tautology | §1 para 2 | "Properly normalized design should use proper normalization techniques" | Circular: defines normalization by referencing normalization |
| Q3 | contradiction | §2 para 1-2 | "All fields must have NOT NULL constraints" vs "Optional fields should allow null values" | Mutually exclusive: NOT NULL on all fields contradicts allowing nulls for optional fields |
| Q4 | duplicate | §3 sentence 1-2 | "Check index design and coverage" + "evaluate database indexing strategy" | Two near-identical directives about indexing in consecutive sentences; >70% overlap |
| Q5 | pseudo-precision | §3 bullet 1 | "enterprise-grade database standards" | Sounds precise but references no specific standard or metric |
| Q6 | cost-ineffective | §3 bullet 2 | "Analyze query execution plans for all possible SQL queries against the schema" | Infinite set of possible queries; exhaustive analysis is infeasible |
| Q7 | missing-context | §4 bullet 3 | "Aligning with the existing data dictionary" | References a data dictionary without specifying its location or format |
| Q8 | low-SN | §5 sentence 1 | "Look for any data modeling concerns that may affect compliance" | Overly broad; "any concerns" with unspecified compliance framework produces noise |
| Q9 | unexecutable | §5 sentence 2 | "Monitor actual query execution times in production environment" | Requires production access; impossible during design review |
| Q10 | infeasible | §6 sentence 1 | "Verify referential integrity across all distributed database shards" | Requires runtime access to distributed system; infeasible in static design review |
