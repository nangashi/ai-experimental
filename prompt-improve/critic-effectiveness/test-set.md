# Test Scenario Set: critic-effectiveness

Generated: 2026-02-11
Purpose: Evaluate the effectiveness critique agent's ability to assess perspective definitions

## Capability Coverage

The test scenarios cover the following key capabilities:
1. **Value Assessment** - Evaluating contribution to review quality (T01, T03, T07)
2. **Boundary Analysis** - Detecting scope overlaps with existing perspectives (T02, T04, T06)
3. **Cross-reference Validation** - Verifying accuracy of perspective references (T04, T05)
4. **Problem Identification** - Enumerating missed issues without the perspective (T01, T03)
5. **Actionability Evaluation** - Assessing whether findings lead to executable improvements (T03, T07)

---

## Test Scenarios

### T01: Well-Defined Specialized Perspective

**Difficulty**: Easy
**Category**: Value Assessment

#### Input

```markdown
# Perspective: Accessibility

## Overview
Evaluate design documents for accessibility considerations in user-facing features.

## Evaluation Scope

This perspective evaluates:
- **Keyboard Navigation**: Can all interactive elements be accessed via keyboard?
- **Screen Reader Support**: Are ARIA labels and semantic HTML properly used?
- **Color Contrast**: Do text and UI elements meet WCAG 2.1 AA standards?
- **Focus Management**: Is focus order logical and visible?
- **Alternative Text**: Are images and icons properly described?

## Out of Scope (Covered by Other Perspectives)

- Implementation complexity → consistency で扱う
- Performance impact of accessibility features → performance で扱う
- Security implications of ARIA attributes → security で扱う

## Scoring Guidelines

**Bonus Criteria** (+2 points each):
- Identifies specific WCAG violation with recommendation
- Provides keyboard shortcut design for complex interactions
- Suggests semantic HTML improvements

**Penalty Criteria** (-2 points each):
- Makes accessibility claims without citing WCAG standards
- Suggests inaccessible patterns (e.g., click-only actions)
- Confuses accessibility with general usability

## Expected Output Format

### Accessibility Issues
- [Issue]: [Description]
- [WCAG Criterion]: [Reference]
- [Recommendation]: [Specific fix]

### Best Practices
- [Practice]: [Rationale]
```

**Existing Perspectives**: consistency, performance, security, reliability, structural-quality

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T01-C1 | Value Recognition | Identifies 3+ specific accessibility issues that would be missed without this perspective (e.g., keyboard traps, missing ARIA labels, contrast failures) | Identifies 1-2 issues but lacks specificity or concrete examples | Cannot enumerate specific missed issues | 1.0 |
| T01-C2 | Actionability Confirmation | Confirms that all recommendations are actionable (WCAG references, specific HTML/CSS fixes) and not vague warnings | Notes general actionability but doesn't verify specific examples | Overlooks actionability or makes incorrect claims | 1.0 |
| T01-C3 | Boundary Clarity | Confirms the out-of-scope section correctly delegates to other perspectives without overlap | Mentions boundary but doesn't verify all delegations | Misses boundary analysis | 0.5 |
| T01-C4 | Bonus/Penalty Appropriateness | Evaluates whether bonus/penalty criteria align with the perspective's core focus | Makes superficial comment on criteria | Doesn't address criteria | 0.5 |

#### Expected Key Behaviors
- Enumerate at least 3 concrete accessibility issues that would be missed (keyboard traps, missing alt text, contrast violations)
- Confirm that recommendations reference specific standards (WCAG 2.1)
- Verify that out-of-scope delegations are accurate
- Recognize that bonus/penalty criteria are well-aligned with accessibility domain

#### Anti-patterns
- Cannot provide concrete examples of missed issues
- Claims the perspective overlaps with "usability" without distinguishing accessibility-specific concerns
- Overlooks the specificity of scoring criteria
- Confuses accessibility domain with general design quality

---

### T02: Perspective with Scope Overlap

**Difficulty**: Medium
**Category**: Boundary Analysis

#### Input

```markdown
# Perspective: Code Quality

## Overview
Evaluate design documents for code maintainability and implementation best practices.

## Evaluation Scope

This perspective evaluates:
- **Naming Conventions**: Are component/variable names clear and consistent?
- **Error Handling**: Are error cases identified and handled appropriately?
- **Testing Strategy**: Is the design testable with clear test scenarios?
- **Code Organization**: Is the module structure logical and modular?
- **Documentation Completeness**: Are public APIs and complex logic documented?

## Out of Scope (Covered by Other Perspectives)

- Security vulnerabilities → security で扱う
- Performance optimization → performance で扱う
- Design pattern selection → structural-quality で扱う

## Scoring Guidelines

**Bonus Criteria** (+2 points each):
- Identifies inconsistent naming patterns with examples
- Proposes comprehensive error handling strategy
- Suggests test case improvements

**Penalty Criteria** (-2 points each):
- Makes claims without supporting evidence
- Suggests over-engineering solutions
- Misidentifies best practices from outdated standards
```

**Existing Perspectives**: consistency, performance, security, reliability, structural-quality

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T02-C1 | Scope Overlap Detection | Identifies that "Naming Conventions" and "Code Organization" overlap with consistency, and "Testing Strategy" overlaps with reliability | Identifies 1-2 overlaps but misses others | Doesn't detect overlaps or makes incorrect claims | 1.0 |
| T02-C2 | Specific Overlap Evidence | Provides specific examples of which scope items conflict (e.g., "Naming Conventions" is part of consistency's code convention evaluation) | Mentions overlaps without specific evidence | No evidence provided | 1.0 |
| T02-C3 | Out-of-Scope Accuracy | Verifies that delegations to security, performance, structural-quality are accurate | Partially verifies delegations | Doesn't verify delegations | 0.5 |
| T02-C4 | Severity Assessment | Judges whether the overlaps are fundamental design flaws requiring perspective redesign or minor refinements | Makes general statement about severity | No severity assessment | 1.0 |

#### Expected Key Behaviors
- Detect that naming conventions, code organization, and testing strategy overlap with existing perspectives
- Reference specific existing perspective scopes when identifying overlaps (e.g., "consistency already covers naming conventions")
- Distinguish between minor and major overlaps
- Recommend redesign or scope refinement based on overlap severity

#### Anti-patterns
- Claims no overlaps exist when multiple are present
- Identifies overlaps that don't actually exist
- Doesn't assess the severity of overlaps
- Accepts the perspective as-is despite significant overlap issues

---

### T03: Perspective with Vague Value Proposition

**Difficulty**: Medium
**Category**: Value Assessment, Problem Identification

#### Input

```markdown
# Perspective: Design Excellence

## Overview
Evaluate design documents for overall quality, elegance, and long-term sustainability.

## Evaluation Scope

This perspective evaluates:
- **Design Elegance**: Is the solution elegant and simple?
- **Future-Proofing**: Will the design adapt to future requirements?
- **Holistic Quality**: Does the design exhibit overall excellence?
- **Best Practices Alignment**: Does the design follow industry best practices?
- **Sustainability**: Is the design maintainable over time?

## Out of Scope (Covered by Other Perspectives)

- Specific security issues → security で扱う
- Detailed performance metrics → performance で扱う

## Scoring Guidelines

**Bonus Criteria** (+2 points each):
- Identifies elegant design patterns
- Highlights forward-thinking decisions
- Recognizes holistic quality improvements

**Penalty Criteria** (-2 points each):
- Overlooks design elegance
- Accepts mediocre solutions
- Ignores long-term implications
```

**Existing Perspectives**: consistency, performance, security, reliability, structural-quality

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T03-C1 | Vagueness Detection | Identifies that all 5 scope items are vague and unmeasurable (elegance, future-proofing, holistic quality, best practices, sustainability lack concrete criteria) | Identifies 2-4 vague items | Identifies 0-1 or claims scope is clear | 1.0 |
| T03-C2 | Missed Issues Enumeration | Recognizes inability to enumerate 3+ specific problems that would be missed without this perspective (due to vagueness) | Notes difficulty in enumeration but doesn't emphasize the fundamental issue | Claims specific issues can be enumerated | 1.0 |
| T03-C3 | Actionability Critique | Identifies that bonus/penalty criteria don't lead to actionable improvements ("注意すべき" pattern - recognition without action) | Mentions actionability concern but doesn't emphasize severity | Accepts criteria as actionable | 1.0 |
| T03-C4 | Scope Redundancy | Recognizes that vague scope items overlap with existing perspectives (e.g., sustainability→reliability, best practices→structural-quality) | Identifies 1-2 redundancies | Doesn't identify redundancies | 0.5 |
| T03-C5 | Redesign Necessity | Concludes that the perspective requires fundamental redesign due to lack of value proposition | Suggests improvements but doesn't call for redesign | Accepts the perspective with minor changes | 1.0 |

#### Expected Key Behaviors
- Identify that all scope items are subjective and lack measurable criteria
- Recognize inability to enumerate concrete missed issues
- Flag that scoring criteria promote vague observations rather than actionable recommendations
- Recommend fundamental redesign due to lack of clear value proposition
- Distinguish this from perspectives with minor issues

#### Anti-patterns
- Accepts vague terms like "elegance" and "holistic quality" as sufficient
- Claims concrete problems can be identified from these vague criteria
- Suggests minor wording changes instead of fundamental redesign
- Confuses "sounds important" with "provides specific value"

---

### T04: Perspective with Inaccurate Cross-References

**Difficulty**: Medium
**Category**: Boundary Analysis, Cross-reference Validation

#### Input

```markdown
# Perspective: API Design Quality

## Overview
Evaluate design documents for REST API design quality and developer experience.

## Evaluation Scope

This perspective evaluates:
- **Endpoint Naming**: Are API endpoints following REST conventions?
- **HTTP Method Appropriateness**: Are GET/POST/PUT/DELETE used correctly?
- **Request/Response Structure**: Are payloads well-structured and documented?
- **Error Response Design**: Are error messages clear and actionable?
- **Versioning Strategy**: Is API versioning clearly defined?

## Out of Scope (Covered by Other Perspectives)

- Authentication/Authorization mechanisms → security で扱う
- Rate limiting and throttling → performance で扱う
- Database transaction handling → reliability で扱う
- Code implementation patterns → consistency で扱う
- API documentation completeness → structural-quality で扱う

## Scoring Guidelines

**Bonus Criteria** (+2 points each):
- Identifies RESTful design violations with corrections
- Proposes improved error response schema
- Suggests versioning strategy improvements

**Penalty Criteria** (-2 points each):
- Suggests non-RESTful patterns without justification
- Overlooks error handling edge cases
- Proposes breaking changes without migration strategy
```

**Existing Perspectives Summary**:
- **security**: Authentication, authorization, input validation, encryption, credential management
- **performance**: Response time optimization, caching strategies, query optimization, resource usage
- **reliability**: Error recovery, fault tolerance, data consistency, retry mechanisms
- **consistency**: Code conventions, naming patterns, architectural alignment, interface design
- **structural-quality**: Modularity, design patterns, SOLID principles, component boundaries

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T04-C1 | Incorrect Reference Detection | Identifies that "Database transaction handling → reliability" and "API documentation completeness → structural-quality" are inaccurate (reliability covers fault tolerance but not transaction handling; structural-quality covers design patterns but not documentation) | Identifies 1 incorrect reference | Doesn't identify incorrect references or makes false claims | 1.0 |
| T04-C2 | Missing Scope Item | Identifies that "Error Response Design" (in scope) overlaps with "Error recovery" in reliability perspective, but isn't acknowledged in out-of-scope section | Notes potential overlap but doesn't identify the specific missing delegation | Doesn't identify the missing delegation | 1.0 |
| T04-C3 | Accurate Reference Verification | Confirms that "Authentication/Authorization → security" and "Rate limiting → performance" are accurate | Partially verifies references | Doesn't verify accurate references | 0.5 |
| T04-C4 | Correction Recommendation | Recommends specific corrections to the out-of-scope section (remove or correct inaccurate references, add missing delegation for error response design) | Makes general recommendation without specifics | Doesn't recommend corrections | 1.0 |

#### Expected Key Behaviors
- Identify at least 2 inaccurate cross-references by comparing scope items to existing perspective summaries
- Distinguish between accurate references (auth→security, rate limiting→performance) and inaccurate ones
- Note missing delegation for error response design (overlaps with reliability)
- Provide specific corrections to improve boundary clarity

#### Anti-patterns
- Claims all cross-references are accurate when inaccuracies exist
- Identifies issues that don't exist (false positives)
- Doesn't verify references against existing perspective summaries
- Makes vague comments about "checking references" without specific findings

---

### T05: Minimal Edge Case - Extremely Narrow Perspective

**Difficulty**: Hard
**Category**: Value Assessment, Cross-reference Validation

#### Input

```markdown
# Perspective: HTTP Status Code Correctness

## Overview
Evaluate design documents for correct usage of HTTP status codes in API responses.

## Evaluation Scope

This perspective evaluates:
- **2xx Success Codes**: Are 200/201/204 used appropriately?
- **4xx Client Error Codes**: Are 400/401/403/404 correctly chosen?
- **5xx Server Error Codes**: Are 500/502/503 properly distinguished?
- **Status Code Consistency**: Are similar operations using consistent status codes?
- **Edge Case Status Codes**: Are less common codes (e.g., 409, 429) used when needed?

## Out of Scope (Covered by Other Perspectives)

- API endpoint design → (no existing perspective covers this)
- Error message content → reliability で扱う
- Authentication mechanisms → security で扱う
- Performance optimization → performance で扱う

## Scoring Guidelines

**Bonus Criteria** (+2 points each):
- Identifies incorrect status code with correct alternative
- Suggests consistent status code pattern across related endpoints
- Recognizes need for less common status codes (e.g., 409 for conflicts)

**Penalty Criteria** (-2 points each):
- Accepts incorrect status codes without comment
- Suggests non-standard status code usage
- Overlooks status code inconsistencies
```

**Existing Perspectives**: consistency, performance, security, reliability, structural-quality

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T05-C1 | Excessive Narrowness Detection | Identifies that the scope is too narrow (HTTP status codes alone don't justify a full perspective) and should be part of a broader API design or consistency perspective | Notes narrowness but doesn't recommend integration | Doesn't detect narrowness issue | 1.0 |
| T05-C2 | Limited Value Assessment | Recognizes that while status code correctness is important, it doesn't warrant a dedicated critique agent (issues are typically caught by linters or API guidelines) | Acknowledges limited scope but doesn't assess value proposition | Claims sufficient value despite narrowness | 1.0 |
| T05-C3 | False Out-of-Scope Detection | Identifies that "API endpoint design → (no existing perspective covers this)" is incorrect notation (should reference a specific perspective or state "not covered by existing perspectives") | Notes odd notation but doesn't identify the issue clearly | Doesn't detect the notation error | 0.5 |
| T05-C4 | Integration Recommendation | Recommends merging this perspective into "consistency" or creating a broader "API Design Quality" perspective that includes status codes as one component | Suggests integration but doesn't specify target | Accepts as standalone perspective | 1.0 |
| T05-C5 | Enumeration Challenge | Recognizes that while 3+ problems can technically be enumerated (wrong 2xx/4xx/5xx codes), these are mechanical checks rather than insight-requiring analysis | Enumerates problems but doesn't assess their nature | Claims sufficient missed issues without qualification | 1.0 |

#### Expected Key Behaviors
- Identify that the scope is too narrow for a dedicated perspective
- Assess that mechanical checks (status code correctness) provide limited value compared to automated tools
- Detect the incorrect notation in out-of-scope section
- Recommend integration into a broader perspective (consistency or API design)
- Distinguish between "can enumerate issues" and "provides meaningful analytical value"

#### Anti-patterns
- Accepts the narrow scope as sufficient for a standalone perspective
- Claims that status code correctness alone justifies a critique agent
- Overlooks the false out-of-scope notation
- Treats all enumerable issues as equally valuable regardless of mechanical vs. analytical nature

---

### T06: Complex Overlap - Partially Redundant Perspective

**Difficulty**: Hard
**Category**: Boundary Analysis, Cross-reference Validation

#### Input

```markdown
# Perspective: System Resilience

## Overview
Evaluate design documents for resilience, fault tolerance, and graceful degradation under failure conditions.

## Evaluation Scope

This perspective evaluates:
- **Failure Mode Analysis**: Are potential failure points identified and mitigated?
- **Circuit Breaker Patterns**: Are circuit breakers used for external dependencies?
- **Retry Strategies**: Are retry mechanisms appropriate and include backoff?
- **Data Consistency Guarantees**: Are consistency models clearly defined for distributed operations?
- **Monitoring and Alerting**: Are health checks and alerts properly configured?

## Out of Scope (Covered by Other Perspectives)

- Input validation → security で扱う
- Query optimization → performance で扱う
- Code error handling → consistency で扱う

## Scoring Guidelines

**Bonus Criteria** (+2 points each):
- Identifies missing failure scenario with mitigation strategy
- Proposes circuit breaker configuration for external calls
- Suggests improved retry strategy with exponential backoff

**Penalty Criteria** (-2 points each):
- Overlooks single points of failure
- Suggests retry without backoff
- Ignores data consistency implications
```

**Existing Perspectives Summary**:
- **security**: Authentication, authorization, input validation, encryption, credential management
- **performance**: Response time optimization, caching strategies, query optimization, resource usage
- **reliability**: Error recovery, fault tolerance, data consistency, retry mechanisms, fallback strategies
- **consistency**: Code conventions, naming patterns, architectural alignment, interface design
- **structural-quality**: Modularity, design patterns, SOLID principles, component boundaries

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T06-C1 | Major Overlap Detection | Identifies that 4 of 5 scope items overlap with reliability perspective: failure mode analysis (fault tolerance), circuit breakers (fallback strategies), retry strategies (retry mechanisms), data consistency (data consistency) | Identifies 2-3 overlapping items | Identifies 0-1 overlapping items | 1.0 |
| T06-C2 | Distinguishing Partial Overlap | Recognizes that "Monitoring and Alerting" may not fully overlap with reliability (operational concerns vs. design-time fault tolerance), requiring clarification of scope boundaries | Notes monitoring as potentially distinct but doesn't analyze depth | Doesn't distinguish partial vs. full overlap | 1.0 |
| T06-C3 | Terminology Redundancy | Identifies that "System Resilience" and existing "reliability" perspective are near-synonyms, suggesting renaming or merging | Notes similarity but doesn't address terminology conflict | Doesn't recognize terminology redundancy | 0.5 |
| T06-C4 | Out-of-Scope Incompleteness | Identifies that the out-of-scope section should acknowledge reliability perspective for the 4 overlapping items | Mentions missing reference but doesn't specify items | Doesn't identify incompleteness | 1.0 |
| T06-C5 | Redesign vs. Merge Decision | Evaluates whether this perspective should be: (a) merged into reliability, (b) focused only on monitoring/operations, or (c) redesigned to focus on aspects not covered by reliability | Suggests one option without evaluation | Doesn't provide clear recommendation | 1.0 |

#### Expected Key Behaviors
- Identify 4 of 5 scope items that directly overlap with reliability perspective
- Distinguish monitoring/alerting as potentially distinct operational concern
- Note that "resilience" and "reliability" are near-synonyms, causing confusion
- Recognize that out-of-scope section doesn't acknowledge reliability perspective
- Recommend either merge or significant redesign to eliminate redundancy

#### Anti-patterns
- Claims no significant overlap with reliability perspective
- Accepts all 5 items as distinct from reliability without analysis
- Doesn't address terminology redundancy between "resilience" and "reliability"
- Suggests minor tweaks instead of fundamental redesign/merge
- Overlooks the missing reliability reference in out-of-scope section

---

### T07: Perspective with Non-Actionable Outputs

**Difficulty**: Hard
**Category**: Actionability Evaluation, Value Assessment

#### Input

```markdown
# Perspective: Technical Debt Awareness

## Overview
Evaluate design documents for awareness and acknowledgment of technical debt implications.

## Evaluation Scope

This perspective evaluates:
- **Debt Recognition**: Does the design acknowledge shortcuts or compromises?
- **Debt Documentation**: Are trade-offs and future refactoring needs documented?
- **Debt Justification**: Are technical debt decisions justified with business context?
- **Debt Impact Assessment**: Are the long-term consequences of debt evaluated?
- **Debt Prioritization**: Are high-priority debt items flagged for future resolution?

## Out of Scope (Covered by Other Perspectives)

- Specific code quality issues → consistency で扱う
- Performance optimization opportunities → performance で扱う
- Security vulnerabilities → security で扱う

## Scoring Guidelines

**Bonus Criteria** (+2 points each):
- Highlights acknowledged technical debt with clear documentation
- Recognizes well-justified trade-offs
- Identifies areas where debt awareness is strong

**Penalty Criteria** (-2 points each):
- Accepts unacknowledged shortcuts without comment
- Overlooks missing trade-off justifications
- Ignores long-term maintenance implications
```

**Existing Perspectives**: consistency, performance, security, reliability, structural-quality

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T07-C1 | Recognition-Only Pattern Detection | Identifies that all bonus criteria reward "recognition," "acknowledgment," and "highlighting" without requiring specific improvements (classic "注意すべき" pattern) | Notes that criteria focus on recognition but doesn't emphasize the actionability gap | Doesn't detect the recognition-only pattern | 1.0 |
| T07-C2 | Actionability Failure Analysis | Analyzes that the perspective doesn't generate actionable outputs (finding "debt is acknowledged" doesn't provide improvement path; finding "debt is not acknowledged" only states the obvious) | Notes limited actionability but doesn't analyze why | Accepts outputs as actionable | 1.0 |
| T07-C3 | Scope Ambiguity | Identifies that all 5 scope items are subjective and lack measurable criteria (what constitutes "adequate" documentation, "sufficient" justification, or "appropriate" prioritization?) | Notes some ambiguity but doesn't emphasize scope-wide issue | Accepts scope as sufficiently clear | 1.0 |
| T07-C4 | Value Proposition Weakness | Recognizes that the perspective's value is limited because: (1) it doesn't identify specific debt, (2) it doesn't recommend debt reduction strategies, (3) it only evaluates meta-information (documentation of debt, not debt itself) | Notes limited value but doesn't provide structured reasoning | Claims sufficient value proposition | 1.0 |
| T07-C5 | Fundamental Redesign Necessity | Concludes that the perspective requires fundamental redesign to focus on identifying actual technical debt (code smells, anti-patterns, design compromises) rather than evaluating documentation of debt | Suggests improvements but doesn't call for redesign | Accepts the perspective with minor modifications | 1.0 |

#### Expected Key Behaviors
- Identify that all scoring criteria reward recognition/acknowledgment rather than actionable improvements
- Analyze why outputs would not be actionable (meta-evaluation doesn't lead to concrete fixes)
- Detect ambiguity in all 5 scope items (lack of measurable criteria)
- Assess limited value proposition (evaluating documentation of debt vs. identifying actual debt)
- Recommend fundamental redesign to focus on concrete technical debt identification

#### Anti-patterns
- Claims that recognizing documented debt is a valuable review output
- Accepts "highlighting well-justified trade-offs" as actionable feedback
- Overlooks the distinction between evaluating debt documentation and identifying actual debt
- Suggests minor wording changes instead of fundamental purpose redesign
- Doesn't recognize the "注意すべき" anti-pattern across all criteria
