# Criteria Effectiveness Analysis (Design Style)

- agent_name: api-design-reviewer
- analyzed_at: 2026-02-12

## Findings

### CE-DS-01: Tautological criterion definition renders evaluation non-operational [severity: critical]
- 内容: Criterion 1 defines RESTful design using the same concept it attempts to evaluate, creating a circular definition that provides no operational guidance.
- 根拠: "RESTful APIs should adhere to RESTful design patterns to ensure RESTful behavior."
- 推奨: Replace with mechanically checkable criteria: "APIs must use HTTP methods according to their semantic meaning: GET for idempotent reads with no side effects, POST for resource creation returning 201 with Location header, PUT for full resource replacement with 200/204, PATCH for partial updates with JSON Patch RFC 6902, DELETE for removal returning 204."
- 検出戦略: Detection Strategy 2 (Tautology test), Detection Strategy 5 (Structural Antipatterns - Tautology)

### CE-DS-02: Direct contradiction in authentication requirements [severity: critical]
- 内容: Criterion 3 contains mutually exclusive requirements that cannot both be satisfied.
- 根拠: "All API endpoints must include authentication mechanisms." immediately followed by "Public-facing APIs should remain accessible without requiring authentication to ensure broad adoption and developer experience."
- 推奨: Resolve the contradiction. Either: (a) "All endpoints except explicitly documented public endpoints (e.g., /health, /docs) must require authentication" or (b) "Endpoints must declare authentication requirement explicitly in OpenAPI spec: 'security: []' for public, 'security: [bearerAuth]' for protected."
- 検出戦略: Detection Strategy 2 (Contradiction test), Detection Strategy 4 (Cross-Criteria Consistency - Contradiction)

### CE-DS-03: Runtime execution required in static review context [severity: critical]
- 内容: Criterion 7 requires executing API calls, which is infeasible in a static design review where APIs are not yet implemented or deployed.
- 根拠: "Verify API integration quality by executing API calls to verify response correctness."
- 推奨: Remove this criterion or replace with static checks: "Integration test scenarios must be documented with: (a) test case ID, (b) request example with all required fields, (c) expected response with status code and body schema, (d) error scenarios and expected error codes."
- 検出戦略: Detection Strategy 3 (Operational Feasibility - Tool requirements), Detection Strategy 5 (Feasibility Antipatterns - runtime observation)

### CE-DS-04: Infeasible exhaustive enumeration requirement [severity: critical]
- 内容: Criterion 4 requires checking "all possible traffic scenarios" which is an infinite set and cannot be exhaustively evaluated.
- 根拠: "API can handle expected load conditions under all possible traffic scenarios"
- 推奨: Replace with bounded, testable criteria: "Design document must specify: (a) expected peak QPS per endpoint, (b) p95 latency target in milliseconds, (c) timeout values for each external dependency, (d) circuit breaker thresholds (error rate % and time window)."
- 検出戦略: Detection Strategy 3 (Operational Feasibility), Detection Strategy 5 (Feasibility Antipatterns - exhaustive enumeration)

### CE-DS-05: Cross-system analysis exceeds single-agent scope [severity: critical]
- 内容: Criterion 6 requires tracing API calls across all microservices, which exceeds practical context limits and cost budgets for a single agent review.
- 根拠: "Tracing all API call chains across all microservices to verify documentation consistency"
- 推奨: Scope to single service boundary: "For each endpoint in this service's API specification: (a) document all external API dependencies with service name, endpoint, and timeout, (b) verify all called endpoints exist in their respective OpenAPI specs (check by name match, not exhaustive tracing)."
- 検出戦略: Detection Strategy 3 (Operational Feasibility - Context requirements), Detection Strategy 5 (Efficiency Antipatterns - cross-system analysis)

### CE-DS-06: Undefined external standard reference [severity: improvement]
- 内容: Criterion 4 references "industry-standard performance benchmarks" without specifying what standard, version, or threshold values to use.
- 根拠: "API latency must meet industry-standard performance benchmarks."
- 推奨: Define explicit thresholds: "API endpoints must specify target latency: (a) p50 < 100ms for synchronous reads, (b) p95 < 500ms for synchronous reads, (c) p99 < 1000ms for synchronous writes, (d) async operations return 202 immediately with job ID."
- 検出戦略: Detection Strategy 2 (Pseudo-precision test), Detection Strategy 5 (Vagueness Antipatterns - external standards without version)

### CE-DS-07: Vague threshold "as needed" enables evasion [severity: improvement]
- 内容: Criterion 4 uses "as needed" without defining when caching is needed, allowing agents to skip checks by claiming it's not needed.
- 根拠: "Caching strategies are implemented as needed"
- 推奨: Define explicit trigger conditions: "Endpoints that return data with update frequency < 1/minute must specify caching strategy with: (a) cache location (client/CDN/server), (b) TTL value, (c) cache invalidation trigger, (d) Cache-Control header values."
- 検出戦略: Detection Strategy 2 (Evasion test), Detection Strategy 5 (Vagueness Antipatterns - "as needed")

### CE-DS-08: Aspirational criterion without detection method [severity: improvement]
- 内容: Criterion 1 requires "appropriate" design without defining appropriateness criteria or how to evaluate it.
- 根拠: "API design is appropriate for the use case"
- 推奨: Remove this aspirational statement or replace with specific checks: "For each endpoint, design document must justify: (a) chosen HTTP method with reference to RFC 9110 section, (b) resource granularity (why this resource boundary vs alternatives), (c) sync vs async choice with latency/complexity tradeoff."
- 検出戦略: Detection Strategy 1 (Classification - Aspirational), Detection Strategy 5 (Vagueness Antipatterns - "appropriate")

### CE-DS-09: Best practices reference without definition [severity: improvement]
- 内容: Criterion 2 requires following "best practices" without defining what those practices are, enabling evasion.
- 根拠: "Error handling follows best practices"
- 推奨: Remove this phrase or integrate into concrete requirements already listed (HTTP status code, error code, message, request ID are already specified in the criterion).
- 検出戦略: Detection Strategy 2 (Evasion test), Detection Strategy 5 (Vagueness Antipatterns - "best practices")

### CE-DS-10: External document reference without location [severity: improvement]
- 内容: Criterion 5 references "project's API validation guidelines" without specifying where to find this document, making the check impossible to execute.
- 根拠: "Following the project's API validation guidelines"
- 推奨: Either: (a) specify exact path: "Following validation rules in docs/api-validation-policy.md section 3.2" or (b) inline the requirements: "All request parameters must have: type, format, required/optional flag, min/max constraints for numbers/strings, enum values if applicable, example value."
- 検出戦略: Detection Strategy 3 (Operational Feasibility), Detection Strategy 5 (Feasibility Antipatterns - references without location)

### CE-DS-11: Aspirational future-focused check without method [severity: improvement]
- 内容: Criterion 5 asks to check for "potential API issues that might arise in future versions" without defining what issues to look for or how to predict them.
- 根拠: "Check for potential API issues that might arise in future versions."
- 推奨: Replace with concrete forward-compatibility checks: "API design must support evolution: (a) all object responses use extensible formats (JSON object, not array at root), (b) required fields list is minimal (prefer optional fields), (c) new optional response fields won't break existing parsers, (d) version deprecation timeline is documented."
- 検出戦略: Detection Strategy 1 (Classification - Aspirational), Detection Strategy 5 (Structural Antipatterns - Aspirational)

### CE-DS-12: Semantic overlap between quality criteria [severity: improvement]
- 内容: Criterion 1's "API design is appropriate for the use case" and Criterion 2's "Error handling follows best practices" both make aspirational quality statements without operational guidance, creating redundant non-actionable checks.
- 根拠: Both statements are judgment-dependent quality assertions that don't add specific checkable requirements beyond what's already listed in concrete sub-bullets.
- 推奨: Remove both aspirational statements and keep only the mechanically checkable sub-criteria already present in each section.
- 検出戦略: Detection Strategy 4 (Cross-Criteria Consistency - Duplication)

### CE-DS-13: Missing backward compatibility criteria in versioning section [severity: info]
- 内容: Criterion 6 addresses versioning strategy but doesn't specify backward compatibility requirements, which is a core concern when versioning APIs.
- 根拠: Criterion 6 only mentions "URL-based versioning strategy (e.g., /v1/, /v2/) exists" without addressing compatibility between versions.
- 推奨: Add: "Version transitions must document: (a) breaking vs non-breaking changes, (b) migration guide from v(n-1) to v(n), (c) deprecation timeline (minimum 6 months), (d) version support matrix showing which versions are actively supported."
- 検出戦略: Detection Strategy 4 (Cross-Criteria Consistency - Gap analysis)

### CE-DS-14: Missing data privacy criteria despite security section [severity: info]
- 内容: Criterion 3 covers authentication and security but doesn't address data privacy, PII handling, or GDPR compliance, which are critical for API design.
- 根拠: Security section focuses on authentication/authorization but omits data handling requirements.
- 推奨: Add to security section or create new criterion: "APIs handling personal data must document: (a) PII fields identification, (b) data retention period, (c) deletion/anonymization mechanisms, (d) data export format for subject access requests, (e) geographic data residency restrictions."
- 検出戦略: Detection Strategy 4 (Cross-Criteria Consistency - Gap analysis)

## Summary

- critical: 5
- improvement: 7
- info: 2
