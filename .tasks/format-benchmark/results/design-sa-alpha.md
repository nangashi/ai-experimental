# Scope Alignment Analysis (Design Style)

- agent_name: api-design-reviewer
- analyzed_at: 2026-02-12

## Findings

### SA-DS-01: Direct Scope Contradiction in Authentication Requirements [severity: critical]
- 内容: Section 3 contains two directly contradictory statements: "All API endpoints must include authentication mechanisms" (line 32) vs "Public-facing APIs should remain accessible without requiring authentication" (line 34). This creates unpredictable agent behavior.
- 根拠: Lines 32-34 present mutually exclusive requirements. An agent cannot simultaneously enforce that all endpoints require authentication and that public APIs should not require authentication.
- 推奨: Remove the contradiction by clarifying that authentication requirements depend on endpoint type, or remove this section entirely as it belongs to security agent scope.
- 検出戦略: Detection Strategy 2 (Boundary Analysis)

### SA-DS-02: Design Review Agent Includes Runtime Testing Execution [severity: critical]
- 内容: Section 7 "Integration Testing Design" instructs the agent to execute API calls ("executing API calls to verify response correctness", line 63), which contradicts the design review purpose stated in the description.
- 根拠: The agent is described as reviewing "design documents" (line 3, 6), but Section 7 requires runtime testing execution which is fundamentally different from static design review.
- 推奨: Remove Section 7 entirely. Integration testing belongs to a dedicated testing agent. If test design review is needed, limit to evaluating test plan completeness without execution.
- 検出戦略: Detection Strategy 3 (Internal Consistency Verification)

### SA-DS-03: Missing Scope Boundary Documentation [severity: critical]
- 内容: The agent definition lacks an "Out of Scope" section and provides no cross-references to adjacent agents (security, performance, testing), making it impossible to determine ownership boundaries in a multi-agent system.
- 根拠: The document includes no explicit boundary markers. When multiple agents review the same design document, overlapping criteria (authentication, performance, testing) will cause duplicated or conflicting feedback.
- 推奨: Add "Out of Scope" section explicitly listing: "Security implementation details (defer to security-reviewer)", "Performance benchmarks (defer to performance-reviewer)", "Test execution (defer to testing-agent)". Add cross-references to related agents.
- 検出戦略: Detection Strategy 2 (Boundary Analysis)

### SA-DS-04: Territory Grab from Security Domain [severity: improvement]
- 内容: Section 3 "Authentication & Security" covers topics that clearly belong to a specialized security agent: JWT/OAuth2 implementation, rate limiting strategies, and CORS configuration.
- 根拠: Lines 36-39 specify security mechanisms that require security expertise to evaluate properly. An API design reviewer evaluating JWT implementation details duplicates work of a security reviewer.
- 推奨: Limit Section 3 to design-level concerns: "Verify that authentication mechanism is specified in the design" without evaluating the security implementation details. Reference security agent for implementation review.
- 検出戦略: Detection Strategy 2 (Boundary Analysis), Detection Strategy 4 (Adversarial Testing)

### SA-DS-05: Territory Grab from Performance Domain [severity: improvement]
- 内容: Section 4 "Performance & Scalability" covers topics that belong to a performance agent: latency benchmarks, load handling verification, and caching strategy evaluation.
- 根拠: Lines 42-46 specify performance requirements ("industry-standard performance benchmarks", "handle expected load conditions under all possible traffic scenarios") that require performance engineering expertise.
- 推奨: Limit Section 4 to design-level concerns: "Verify that pagination is designed for list endpoints" and "Verify that caching strategy is documented". Remove performance benchmark evaluation and load testing requirements.
- 検出戦略: Detection Strategy 2 (Boundary Analysis), Detection Strategy 4 (Adversarial Testing)

### SA-DS-06: Stealth Scope Extension via Vague Future Issue Detection [severity: improvement]
- 内容: Section 5 includes vague instruction "Check for potential API issues that might arise in future versions" (line 50) which could justify reviewing any aspect of the system.
- 根拠: "Potential future issues" is unbounded and adversarially exploitable to extend into performance, security, operations, or any other domain under the guise of "future-proofing".
- 推奨: Remove the vague future issue clause. Limit Section 5 to concrete present-state validation: "Verify request payload validation schema exists and covers all required fields".
- 検出戦略: Detection Strategy 4 (Adversarial Testing)

### SA-DS-07: Stealth Scope Extension into System Architecture [severity: improvement]
- 内容: Section 6 requires "Tracing all API call chains across all microservices" (line 59) which extends into system architecture analysis beyond individual API design.
- 根拠: Cross-microservice call chain analysis requires understanding the entire system architecture, not just individual API design. This belongs to a system architecture reviewer.
- 推奨: Remove the cross-microservice tracing requirement. Limit documentation review to the individual API being designed: "Verify that the API has OpenAPI/Swagger specification and versioning strategy".
- 検出戦略: Detection Strategy 4 (Adversarial Testing)

### SA-DS-08: Scope Statement Too Narrow for Actual Criteria [severity: improvement]
- 内容: The stated scope "API endpoint design, request/response formats, and integration patterns" (line 10) does not cover security, performance, or testing criteria that appear in sections 3, 4, and 7.
- 根拠: Comparing line 10 with sections 3, 4, 7 reveals scope creep. If security/performance/testing are intentional, the scope statement should explicitly include them. If not, those sections should be removed.
- 推奨: Either (A) narrow criteria to match scope statement by removing security/performance/testing sections, or (B) expand scope statement to acknowledge these domains and add boundary documentation for handoff to specialized agents.
- 検出戦略: Detection Strategy 1 (Scope Inventory), Detection Strategy 3 (Internal Consistency)

### SA-DS-09: Circular Definition in RESTful Compliance [severity: info]
- 内容: Section 1 contains circular definition: "RESTful APIs should adhere to RESTful design patterns to ensure RESTful behavior" (line 16) provides no actionable guidance.
- 根拠: The statement defines "RESTful" in terms of itself without specifying what constitutes REST compliance beyond the examples in lines 19-21.
- 推奨: Remove the circular sentence or replace with concrete definition: "APIs should follow REST architectural constraints: stateless communication, resource-based URLs, standard HTTP methods, hypermedia controls where applicable".
- 検出戦略: Detection Strategy 3 (Internal Consistency Verification)

### SA-DS-10: Undefined "Best Practices" Reference [severity: info]
- 内容: Section 2 requires "Error handling follows best practices" (line 28) without defining or referencing what those best practices are.
- 根拠: "Best practices" is subjective and unmeasurable without a concrete reference. Different reviewers may apply different standards.
- 推奨: Either define specific best practices inline or reference an external standard: "Error handling follows RFC 7807 Problem Details standard" or "Error handling follows [Company API Guidelines Document]".
- 検出戦略: Detection Strategy 3 (Internal Consistency Verification)

### SA-DS-11: Vague "As Needed" Clause in Caching [severity: info]
- 内容: Section 4 states "Caching strategies are implemented as needed" (line 46) without defining when caching is needed or what constitutes adequate caching.
- 根拠: "As needed" provides no measurable standard. This could be interpreted as "always required" or "never required" depending on the reviewer.
- 推奨: Replace with concrete requirement: "Caching strategy is documented for any endpoint with read-heavy access patterns (>80% GET requests)" or remove the requirement if caching decisions belong to performance review.
- 検出戦略: Detection Strategy 3 (Internal Consistency Verification)

### SA-DS-12: External Dependency Without Scope Definition [severity: info]
- 内容: Section 5 references "Following the project's API validation guidelines" (line 52) without defining what happens if those guidelines don't exist or how they relate to this agent's scope.
- 根拠: External dependencies create scope ambiguity. If the project guidelines are incomplete or conflict with this agent's criteria, the agent behavior is undefined.
- 推奨: Either (A) make the agent self-contained by defining validation requirements inline, or (B) explicitly state the fallback behavior: "If project guidelines exist, verify compliance. Otherwise, verify JSON Schema validation for all request payloads".
- 検出戦略: Detection Strategy 3 (Internal Consistency Verification)

## Summary

- critical: 3
- improvement: 6
- info: 4
