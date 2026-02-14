# Scope Alignment Analysis (Design Style)

- agent_name: api-design-reviewer
- analyzed_at: 2026-02-12

## Findings

### SA-DS-01: Complete absence of scope boundary documentation [severity: critical]
- 内容: The agent definition lacks any "Out of Scope" section, cross-references to adjacent agents (security, performance, testing), or handoff protocols. This creates ambiguity about where this agent's responsibility ends and others begin.
- 根拠: The entire document has no mention of scope boundaries, related agents, or collaboration protocols. Lines 1-73 contain only in-scope criteria without any exclusionary statements.
- 推奨: Add an explicit "Out of Scope" section listing: (1) Security implementation details (handled by security agent), (2) Performance benchmarking and load testing (handled by performance agent), (3) Test execution and verification (handled by testing agent), (4) Infrastructure configuration (handled by DevOps agent). Add cross-references to these specialized agents.
- 検出戦略: Detection Strategy 2 (Boundary Analysis) - Missing "Out of Scope" documentation

### SA-DS-02: Direct authentication contradiction creates unpredictable behavior [severity: critical]
- 内容: Lines 32-34 contain a direct logical contradiction: "All API endpoints must include authentication mechanisms" immediately followed by "Public-facing APIs should remain accessible without requiring authentication to ensure broad adoption and developer experience." This makes it impossible to know which rule applies.
- 根拠: Line 32: "All API endpoints must include authentication mechanisms. Flag any endpoint that lacks proper authentication." Line 34: "Public-facing APIs should remain accessible without requiring authentication to ensure broad adoption and developer experience."
- 推奨: Resolve the contradiction by clarifying: "All non-public API endpoints must include authentication mechanisms. Public-facing endpoints that are explicitly documented as public may omit authentication for developer accessibility, but should include optional API key support for rate limiting."
- 検出戦略: Detection Strategy 2 (Boundary Analysis) - Internal contradictions; Detection Strategy 3 (Internal Consistency Verification)

### SA-DS-03: Security domain territory grab [severity: improvement]
- 内容: Criterion 3 (Authentication & Security) claims responsibility for security mechanism design (JWT/OAuth2, rate limiting, CORS configuration), which clearly belongs to security specialists. The API design agent should only specify authentication requirements, not design the mechanisms.
- 根拠: Lines 32-40 include: "Token-based authentication (JWT/OAuth2) is designed", "Rate limiting per API key is specified", "CORS origins are explicitly listed". These are security implementation concerns, not API design concerns.
- 推奨: Rename section to "Authentication Requirements" and limit scope to: "Verify that endpoints specify whether authentication is required, and what authorization level is needed." Remove JWT/OAuth2 design, rate limiting implementation, and CORS configuration - defer these to security agent with explicit cross-reference.
- 検出戦略: Detection Strategy 1 (Scope Inventory) - Scope creep; Detection Strategy 4 (Adversarial Scope Testing) - Territory grab

### SA-DS-04: Performance domain territory grab [severity: improvement]
- 内容: Criterion 4 (Performance & Scalability) claims responsibility for performance benchmarking, load handling verification, and caching strategy design, which belong to performance specialists. The API design agent should only design APIs that enable performance optimization, not verify performance outcomes.
- 根拠: Lines 44-47 state: "API latency must meet industry-standard performance benchmarks", "API can handle expected load conditions under all possible traffic scenarios", "Caching strategies are implemented as needed". These require performance testing and infrastructure knowledge beyond API design.
- 推奨: Rename section to "Performance-Friendly Design" and limit scope to: "Verify that pagination is designed for list endpoints, APIs avoid N+1 query patterns, and response payloads support caching headers (ETags, Cache-Control)." Remove performance benchmarking and load verification - defer these to performance agent with explicit cross-reference.
- 検出戦略: Detection Strategy 1 (Scope Inventory) - Scope creep; Detection Strategy 4 (Adversarial Scope Testing) - Territory grab

### SA-DS-05: Testing domain territory grab [severity: improvement]
- 内容: Criterion 7 (Integration Testing Design) extends into test execution ("executing API calls to verify response correctness"), which belongs to QA/testing teams. The API design agent should only verify that APIs are testable and specify test requirements, not execute tests.
- 根拠: Line 63 states: "Verify API integration quality by executing API calls to verify response correctness." This is test execution, not design review.
- 推奨: Rename section to "Testability Requirements" and limit scope to: "Verify that API design documents include testable acceptance criteria and identify critical user flows that require integration testing." Remove test execution responsibility - defer to testing agent with explicit cross-reference.
- 検出戦略: Detection Strategy 1 (Scope Inventory) - Scope creep; Detection Strategy 4 (Adversarial Scope Testing) - Territory grab

### SA-DS-06: Microservice tracing extends far beyond API design scope [severity: improvement]
- 内容: Line 59 requires "Tracing all API call chains across all microservices to verify documentation consistency", which requires full system architecture analysis beyond individual API design. This is system integration analysis, not API design review.
- 根拠: Line 59: "Tracing all API call chains across all microservices to verify documentation consistency". This requires understanding all services, their interactions, and deployment topology.
- 推奨: Limit to single-service scope: "Verify that API documentation includes dependencies on external services and expected integration points." Remove cross-service tracing requirement - defer to architecture/integration agent.
- 検出戦略: Detection Strategy 3 (Internal Consistency Verification) - Scope-criteria mismatch; Detection Strategy 4 (Adversarial Scope Testing) - Stealth creep

### SA-DS-07: Vague scope-expansion language enables unlimited interpretation [severity: improvement]
- 内容: Line 21 states "API design is appropriate for the use case" without defining what "appropriate" means or what use cases are in scope. This vague language could justify reviewing any aspect of the system under the guise of API appropriateness.
- 根拠: Line 21: "API design is appropriate for the use case". No definition of "appropriate" or boundaries on "use case" provided.
- 推奨: Replace with specific checkable criteria: "API design follows REST resource modeling best practices: resources are nouns not verbs, hierarchical relationships use nested paths (/users/{id}/orders), and actions that don't fit CRUD are modeled as sub-resources (/orders/{id}/cancel)."
- 検出戦略: Detection Strategy 4 (Adversarial Scope Testing) - Stealth creep

### SA-DS-08: Circular RESTful definition provides no actionable guidance [severity: improvement]
- 内容: Line 16 states "RESTful APIs should adhere to RESTful design patterns to ensure RESTful behavior", which is a circular definition that provides no concrete guidance and allows arbitrary interpretation of what constitutes "RESTful".
- 根拠: Line 16: "RESTful APIs should adhere to RESTful design patterns to ensure RESTful behavior." The term "RESTful" is defined by referencing itself.
- 推奨: Replace with specific REST constraints: "APIs should follow REST architectural constraints: stateless communication (no server-side session state), resource identification via URIs, standard HTTP methods for operations, hypermedia controls for state transitions (HATEOAS), and layered system design."
- 検出戦略: Detection Strategy 4 (Adversarial Scope Testing) - Fragmentation risk through ambiguous phrasing

### SA-DS-09: External reference to undefined guidelines creates interpretation variance [severity: improvement]
- 内容: Line 52 states "Following the project's API validation guidelines" without specifying what these guidelines are or where to find them. This external reference allows different agents to interpret validation requirements differently based on assumed guidelines.
- 根拠: Line 52: "Following the project's API validation guidelines". No such guidelines are defined in this document or referenced with a specific location.
- 推奨: Either: (1) Remove the reference and provide inline validation criteria, or (2) Add a "References" section with explicit links to external guidelines documents. Prefer option 1 for self-contained agent definitions.
- 検出戦略: Detection Strategy 4 (Adversarial Scope Testing) - Fragmentation risk through undefined references

### SA-DS-10: Forward-looking concern enables unlimited scope expansion [severity: info]
- 内容: Line 50 instructs to "Check for potential API issues that might arise in future versions", which is open-ended and could justify reviewing any hypothetical future scenario, expanding scope indefinitely.
- 根拠: Line 50: "Check for potential API issues that might arise in future versions." No boundaries on what "future versions" means or how far forward to project.
- 推奨: Limit to immediate versioning concerns: "Check that current API design allows for backward-compatible additions (e.g., optional fields can be added without breaking clients, new endpoints can be added without conflicts)."
- 検出戦略: Detection Strategy 4 (Adversarial Scope Testing) - Stealth creep through forward-looking language

### SA-DS-11: Severity classification lacks domain ownership mapping [severity: info]
- 内容: Lines 69-72 define severity levels (critical, significant, moderate, minor) but don't clarify which domains this agent has authority to assign these severities. For example, can this agent mark security issues as "critical" or should those defer to security agent?
- 根拠: Lines 69-72 list severity definitions but provide no guidance on cross-domain severity assignment. Line 69 mentions "security breaches" as API design critical issues, conflating domains.
- 推奨: Add domain-specific severity guidance: "Assign severity levels for API design issues only. For issues in other domains (security, performance, testing), note the concern and defer severity assessment to the specialized agent."
- 検出戦略: Detection Strategy 3 (Internal Consistency Verification) - Severity inconsistencies

## Summary

- critical: 2
- improvement: 7
- info: 2
