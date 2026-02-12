# Answer Key: alpha CE (Criteria Effectiveness)

12 planted problems in api-design-reviewer.

| ID | Type | Section | Problematic Text | Why It's a Problem |
|----|------|---------|-------------------|-------------------|
| P1 | tautology | §1 para 1 | "RESTful APIs should adhere to RESTful design patterns to ensure RESTful behavior" | Circular: defines REST by referencing REST, adds no operational guidance |
| P2 | vague | §1 bullet 3 | "API design is appropriate for the use case" | No criteria for "appropriate"; subjective, unactionable |
| P3 | duplicate | §2 title+content | "error response formats" (title) + "error handling in API responses" (subtitle) | Section title and description overlap >70%; the entire section is one concern split into two framings |
| P4 | vague | §2 bullet 3 | "Error handling follows best practices" | Unspecified "best practices"; no reference to which practices |
| P5 | contradiction | §3 para 1-2 | "All endpoints must include authentication" vs "Public-facing APIs should remain accessible without authentication" | Mutually exclusive directives with no resolution strategy |
| P6 | pseudo-precision | §4 sentence 1 | "industry-standard performance benchmarks" | Sounds precise but no specific standard (P99 latency? Which benchmark?) |
| P7 | infeasible | §4 bullet 2 | "all possible traffic scenarios" | Infinite set; impossible to verify exhaustively |
| P8 | vague | §4 bullet 3 | "Caching strategies are implemented as needed" | "as needed" provides no decision criteria for when caching is needed |
| P9 | low-SN | §5 sentence 1 | "potential API issues that might arise in future versions" | Speculative, unfalsifiable; any API could have "potential future issues" |
| P10 | missing-context | §5 bullet 2 | "Following the project's API validation guidelines" | References guidelines that are not specified or linked |
| P11 | cost-ineffective | §6 bullet 3 | "Tracing all API call chains across all microservices to verify documentation consistency" | Requires exhaustive cross-service tracing; far exceeds single-agent scope |
| P12 | unexecutable | §7 sentence 1 | "executing API calls to verify response correctness" | Design review cannot execute live API calls; requires runtime environment |
