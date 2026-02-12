# Test Scenario Set for critic-effectiveness

## Agent Overview
- **Agent Name**: critic-effectiveness
- **Main Task**: Evaluate the effectiveness of perspective definitions by analyzing their contribution to review quality and boundary clarity with existing perspectives
- **Input**: Perspective definition file path
- **Output**: Structured critique with critical issues, improvement suggestions, and confirmations
- **Key Capabilities**:
  1. Contribution Analysis - Identify problems that would be missed without this perspective
  2. Boundary Verification - Detect scope overlaps with existing perspectives
  3. Cross-reference Validation - Verify accuracy of out-of-scope references
  4. Actionability Assessment - Ensure the perspective leads to concrete, fixable improvements
  5. Scope Focus Evaluation - Assess whether the perspective is appropriately focused

---

## Test Scenarios

### T01: Missing Contribution Evidence

**Difficulty**: Easy
**Category**: Contribution Analysis

#### Input

```markdown
# Perspective: Documentation Quality

## Purpose
Evaluate the completeness and clarity of documentation.

## Evaluation Scope (5 items)
1. API documentation completeness
2. Code comment quality
3. README file structure
4. Architecture diagram presence
5. User guide availability

## Out-of-Scope (with references)
- Code implementation quality → Code Quality perspective
- Test coverage → Testing perspective

## Scoring Guidelines

### Bonus (Additional Points)
- Comprehensive API examples: +1
- Interactive documentation: +0.5

### Penalty (Point Deductions)
- Missing critical sections: -1
- Outdated information: -0.5
```

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T01-C1 | Contribution identification | Identifies 3+ specific problems that would be missed without this perspective, with concrete examples | Identifies 1-2 problems or examples lack specificity | Does not identify missed problems or examples are too vague | 1.0 |
| T01-C2 | Actionability verification | Verifies that each identified problem leads to concrete, fixable improvements (not just "be aware of") | Mentions actionability but verification is incomplete | Does not verify actionability | 1.0 |
| T01-C3 | Scope focus assessment | Assesses whether the 5 scope items are appropriately focused and not too broad/narrow | Mentions scope focus but assessment is superficial | Does not assess scope focus | 0.5 |

#### Expected Key Behaviors
- Identify concrete examples like "Missing API endpoint parameters" or "Outdated version references"
- Verify that findings lead to actionable fixes (e.g., "Add parameter documentation" not just "Improve docs")
- Assess whether scope covers a coherent set of related concerns

#### Anti-patterns
- Accepting vague contribution claims without concrete examples
- Not verifying whether identified problems lead to specific improvements
- Ignoring scope focus evaluation

---

### T02: Scope Overlap Detection

**Difficulty**: Medium
**Category**: Boundary Verification

#### Input

```markdown
# Perspective: Error Handling

## Purpose
Evaluate error handling and recovery mechanisms.

## Evaluation Scope (5 items)
1. Exception handling coverage
2. Error message clarity
3. Retry logic implementation
4. Input validation errors
5. Fallback mechanism design

## Out-of-Scope (with references)
- Security vulnerabilities → Security perspective
- Performance impact of error handling → Performance perspective

## Existing Perspectives Summary
- Security: Input validation, authentication failures, authorization errors, SQL injection prevention, XSS protection
- Reliability: System stability, error recovery, failover mechanisms, circuit breakers, graceful degradation
- Code Quality: Code structure, naming conventions, complexity metrics, SOLID principles, design patterns

## Scoring Guidelines

### Bonus (Additional Points)
- Comprehensive error logging: +1
- User-friendly error messages: +0.5

### Penalty (Point Deductions)
- Silent failures: -1
- Exposing sensitive information in errors: -0.5
```

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T02-C1 | Overlap detection with Security | Identifies that "Input validation errors" overlaps with Security's "Input validation" scope item and provides specific evidence | Mentions overlap but evidence is incomplete or vague | Does not detect the overlap | 1.0 |
| T02-C2 | Overlap detection with Reliability | Identifies that "Retry logic" and "Fallback mechanism" overlap with Reliability's "error recovery", "failover", and "graceful degradation" scope items with specific evidence | Mentions overlap but evidence is incomplete | Does not detect the overlap | 1.0 |
| T02-C3 | Boundary recommendation | Recommends clear boundary definition (e.g., limit to "application-level business logic errors" and exclude security/infrastructure errors) | Mentions need for boundary clarification but recommendation lacks specificity | Does not recommend boundary clarification | 1.0 |
| T02-C4 | Penalty scoring overlap detection | Identifies that the penalty "Exposing sensitive information in errors" overlaps with Security perspective | Mentions the penalty issue but analysis is incomplete | Does not identify the penalty overlap | 0.5 |

#### Expected Key Behaviors
- Compare each of the 5 scope items against existing perspectives' scope systematically
- Provide specific evidence of overlap (e.g., "Item 4 'Input validation errors' duplicates Security's 'Input validation'")
- Recommend explicit scope boundaries to prevent overlap
- Check bonus/penalty criteria for cross-perspective conflicts

#### Anti-patterns
- Only checking perspective names without comparing specific scope items
- Declaring "no overlap" without systematic comparison
- Ignoring bonus/penalty criteria when checking boundaries

---

### T03: Accurate Cross-Reference Validation

**Difficulty**: Medium
**Category**: Cross-reference Validation

#### Input

```markdown
# Perspective: API Design

## Purpose
Evaluate RESTful API design quality and consistency.

## Evaluation Scope (5 items)
1. HTTP method usage appropriateness
2. URL structure consistency
3. Response status code correctness
4. Request/response schema design
5. Versioning strategy

## Out-of-Scope (with references)
- API response time → Performance perspective
- Authentication implementation → Security perspective
- Database query optimization → Performance perspective
- Rate limiting configuration → Security perspective

## Existing Perspectives Summary
- Security: Authentication, authorization, input validation, encryption, security headers
- Performance: Response time, throughput, resource usage, caching, database query optimization
- Code Quality: Code structure, naming, complexity, design patterns

## Scoring Guidelines

### Bonus (Additional Points)
- OpenAPI/Swagger documentation: +1
- HATEOAS implementation: +0.5

### Penalty (Point Deductions)
- Inconsistent naming conventions: -1
- Missing error response schemas: -0.5
```

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T03-C1 | Valid reference detection | Identifies that "API response time → Performance" and "Database query optimization → Performance" are valid references (Performance includes these) | Identifies only 1 valid reference or verification is incomplete | Does not verify valid references | 1.0 |
| T03-C2 | Invalid reference detection | Identifies that "Rate limiting configuration → Security" is invalid (Security perspective does not include rate limiting, which is typically a Performance/Availability concern) | Mentions the reference issue but analysis is incomplete | Does not detect the invalid reference | 1.0 |
| T03-C3 | Reference correction recommendation | Recommends correcting "Rate limiting" reference to Performance or Reliability perspective | Mentions need for correction but recommendation is vague | Does not recommend correction | 0.5 |

#### Expected Key Behaviors
- Cross-check each out-of-scope reference against the existing perspectives summary
- Verify that referenced perspectives actually include the delegated scope
- Identify mismatched references and recommend correct perspective assignment
- Distinguish between valid and invalid cross-references

#### Anti-patterns
- Assuming all references are correct without verification
- Not checking whether referenced perspectives actually cover the delegated items
- Failing to recommend alternative references when delegation is incorrect

---

### T04: Vague Value Proposition

**Difficulty**: Medium
**Category**: Contribution Analysis

#### Input

```markdown
# Perspective: System Design Quality

## Purpose
Evaluate overall system design quality.

## Evaluation Scope (5 items)
1. Architectural decisions appropriateness
2. Component interaction clarity
3. Design pattern usage
4. System scalability considerations
5. Maintainability factors

## Out-of-Scope (with references)
- Code-level implementation → Code Quality perspective
- Performance benchmarks → Performance perspective

## Existing Perspectives Summary
- Code Quality: Code structure, naming, complexity, SOLID principles, design patterns
- Performance: Response time, throughput, scalability, resource usage
- Maintainability: Code readability, modularity, testability, documentation

## Scoring Guidelines

### Bonus (Additional Points)
- Well-documented design decisions: +1
- Clear architecture diagrams: +0.5

### Penalty (Point Deductions)
- Overcomplicated architecture: -1
- Missing component relationships: -0.5
```

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T04-C1 | Vague scope detection | Identifies that scope items like "Architectural decisions appropriateness", "Component interaction clarity", and "Maintainability factors" are too vague and overlap with multiple existing perspectives | Mentions vagueness but analysis is incomplete | Does not detect vague scope items | 1.0 |
| T04-C2 | Overlap with existing perspectives | Identifies that "Design pattern usage" duplicates Code Quality's scope, "System scalability" duplicates Performance's scope, and "Maintainability factors" duplicates Maintainability perspective | Identifies 1-2 overlaps but misses others | Does not identify overlaps | 1.0 |
| T04-C3 | Critical issue classification | Classifies this as a "Critical Issue" requiring fundamental redesign because the perspective lacks clear unique contribution | Mentions problems but does not classify as critical | Does not recognize the severity | 1.0 |
| T04-C4 | Specific improvement recommendation | Recommends either (1) narrowing focus to specific architectural aspects not covered elsewhere, or (2) deprecating this perspective in favor of existing ones | Mentions need for change but recommendation lacks specificity | Does not provide actionable recommendation | 0.5 |

#### Expected Key Behaviors
- Identify when scope items are too broad/vague to provide clear evaluation criteria
- Detect systematic overlap with multiple existing perspectives
- Escalate to "Critical Issue" when perspective lacks unique value
- Recommend specific focus areas or perspective consolidation

#### Anti-patterns
- Accepting vague scope items without questioning their evaluability
- Not comparing against multiple existing perspectives systematically
- Downplaying fundamental design issues as minor improvements
- Providing generic recommendations without specific focus areas

---

### T05: Overly Narrow Scope

**Difficulty**: Hard
**Category**: Scope Focus Evaluation

#### Input

```markdown
# Perspective: GraphQL Mutation Naming Consistency

## Purpose
Evaluate consistency of GraphQL mutation naming conventions.

## Evaluation Scope (5 items)
1. Mutation name verb selection (create/update/delete consistency)
2. Object name singularity/plurality alignment
3. Camel case vs snake case consistency
4. Prefix/suffix pattern adherence
5. CRUD operation naming standards

## Out-of-Scope (with references)
- Query naming conventions → API Design perspective
- Mutation implementation logic → Code Quality perspective
- Mutation performance → Performance perspective

## Existing Perspectives Summary
- API Design: RESTful design, GraphQL schema design, endpoint naming, versioning
- Code Quality: Naming conventions, code structure, design patterns
- Consistency: Cross-system naming consistency, pattern adherence, style guide compliance

## Scoring Guidelines

### Bonus (Additional Points)
- Comprehensive naming guide documentation: +1
- Automated linting rules: +0.5

### Penalty (Point Deductions)
- Mixed naming conventions: -1
- Inconsistent verb usage: -0.5
```

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T05-C1 | Narrow scope detection | Identifies that this perspective is overly narrow, focusing only on GraphQL mutations when naming consistency should be evaluated more broadly | Mentions narrowness but analysis lacks depth | Does not detect the overly narrow scope | 1.0 |
| T05-C2 | Overlap with existing perspectives | Identifies that naming consistency is already covered by "Consistency" perspective and code naming by "Code Quality" perspective | Mentions overlap with 1 perspective but misses the other | Does not identify the overlap | 1.0 |
| T05-C3 | Consolidation recommendation | Recommends consolidating this into the existing Consistency or API Design perspective as a sub-criterion rather than maintaining a separate perspective | Mentions consolidation but recommendation is vague | Does not recommend consolidation | 1.0 |
| T05-C4 | Cost-benefit analysis | Analyzes that maintaining a separate perspective for this narrow scope has low value compared to integration into broader perspective | Mentions value concern but analysis is incomplete | Does not perform cost-benefit analysis | 0.5 |

#### Expected Key Behaviors
- Recognize when a perspective's scope is too narrow to justify separate evaluation
- Check if the narrow scope is already covered by existing broader perspectives
- Recommend consolidation into existing perspectives as sub-criteria
- Consider maintenance cost vs. evaluation value

#### Anti-patterns
- Accepting narrow scope without questioning its necessity as separate perspective
- Not checking if broader perspectives already cover the narrow scope
- Recommending creation of multiple narrow perspectives instead of consolidation
- Ignoring the practical overhead of maintaining too many perspectives

---

### T06: Missing Actionability Verification

**Difficulty**: Hard
**Category**: Actionability Assessment

#### Input

```markdown
# Perspective: Code Readability Awareness

## Purpose
Raise awareness about code readability importance.

## Evaluation Scope (5 items)
1. Variable naming clarity
2. Function complexity perception
3. Comment sufficiency awareness
4. Code organization understanding
5. Readability best practice knowledge

## Out-of-Scope (with references)
- Actual code implementation → Code Quality perspective
- Performance optimization → Performance perspective

## Existing Perspectives Summary
- Code Quality: Code structure, naming conventions, complexity metrics, SOLID principles

## Scoring Guidelines

### Bonus (Additional Points)
- Demonstrates readability awareness: +1
- Mentions readability best practices: +0.5

### Penalty (Point Deductions)
- Shows no readability consideration: -1
- Uses unclear naming patterns: -0.5
```

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T06-C1 | Non-actionable output pattern detection | Identifies that scope items use "awareness", "perception", "understanding", "knowledge" which lead to recognition-only outputs rather than concrete improvements | Identifies some awareness language but analysis is incomplete | Does not detect the non-actionable pattern | 1.0 |
| T06-C2 | Bonus/penalty actionability analysis | Identifies that bonus "Demonstrates awareness" and penalty "Shows no consideration" evaluate mindset rather than concrete, fixable issues | Mentions the issue but analysis lacks depth | Does not analyze bonus/penalty actionability | 1.0 |
| T06-C3 | Critical issue classification | Classifies this as a "Critical Issue" because the perspective fundamentally cannot lead to actionable improvements - it evaluates awareness rather than concrete changes | Mentions problems but does not classify as critical | Does not recognize the fundamental flaw | 1.0 |
| T06-C4 | Concrete reformulation recommendation | Recommends reformulating scope to concrete, measurable criteria (e.g., "Variable names follow domain terminology", "Functions under 20 lines", "Public APIs have documentation") | Mentions need for concrete criteria but examples are vague | Does not provide specific reformulation guidance | 0.5 |

#### Expected Key Behaviors
- Detect when evaluation criteria focus on "awareness" or "understanding" rather than concrete artifacts
- Verify that identified problems can lead to specific, implementable fixes
- Distinguish between "recognize the issue" and "fix the issue" outcomes
- Recommend transformation to concrete, measurable criteria

#### Anti-patterns
- Accepting "awareness" or "consideration" as valid evaluation outcomes
- Not checking whether perspective outputs lead to actionable fixes
- Confusing "identifying a problem" with "having a fixable problem"
- Providing generic advice like "be more specific" without concrete examples

---

### T07: Complex Multi-Perspective Boundary Issue

**Difficulty**: Hard
**Category**: Boundary Verification + Cross-reference Validation

#### Input

```markdown
# Perspective: Data Validation

## Purpose
Evaluate data validation mechanisms across all system layers.

## Evaluation Scope (5 items)
1. Client-side validation implementation
2. API-level request validation
3. Database constraint validation
4. Business rule validation logic
5. Error response handling for validation failures

## Out-of-Scope (with references)
- Security validation (SQL injection prevention) → Security perspective
- Input sanitization for XSS → Security perspective
- Validation performance impact → Performance perspective

## Existing Perspectives Summary
- Security: Input validation for security, SQL injection prevention, XSS protection, authentication, authorization
- Error Handling: Exception handling, error messages, retry logic, input validation errors, fallback mechanisms
- Code Quality: Code structure, validation logic organization, error handling patterns
- Reliability: System stability, error recovery, graceful degradation

## Scoring Guidelines

### Bonus (Additional Points)
- Comprehensive validation coverage across all layers: +1
- User-friendly validation error messages: +0.5
- Centralized validation rule management: +0.5

### Penalty (Point Deductions)
- Missing validation at critical layers: -1
- Exposing internal validation logic in error messages: -0.5
- Inconsistent validation rules across layers: -0.5
```

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T07-C1 | Security overlap detection | Identifies that "API-level request validation" and "Database constraint validation" overlap with Security's "Input validation for security" despite the out-of-scope reference attempt | Identifies overlap with 1 item or evidence is incomplete | Does not detect Security overlap | 1.0 |
| T07-C2 | Error Handling overlap detection | Identifies that "Error response handling for validation failures" completely duplicates Error Handling perspective's "Input validation errors" scope item | Mentions overlap but does not recognize complete duplication | Does not detect Error Handling overlap | 1.0 |
| T07-C3 | Code Quality overlap detection | Identifies that "Business rule validation logic" overlaps with Code Quality's "validation logic organization" and "error handling patterns" | Mentions overlap but analysis is incomplete | Does not detect Code Quality overlap | 0.5 |
| T07-C4 | Multi-perspective boundary recommendation | Recommends clear layered boundaries: distinguish between (1) security-focused validation (→Security), (2) business logic validation (this perspective), (3) error handling patterns (→Error Handling), and (4) implementation quality (→Code Quality) | Mentions need for boundaries but recommendation lacks layered clarity | Does not provide multi-perspective boundary solution | 1.0 |
| T07-C5 | Bonus criteria boundary issue | Identifies that bonus "User-friendly validation error messages" overlaps with Error Handling's scope, and "Centralized validation rule management" overlaps with Code Quality's organizational concerns | Identifies 1 bonus overlap but misses the other | Does not identify bonus overlaps | 0.5 |
| T07-C6 | Critical vs improvement classification | Correctly classifies this as either "Critical Issue" (requiring fundamental redesign to separate concerns) or "Improvement Suggestion" with very specific boundary definitions - with clear rationale | Provides classification but rationale is weak | Does not provide appropriate classification | 0.5 |

#### Expected Key Behaviors
- Systematically check each scope item against multiple existing perspectives
- Identify overlaps even when out-of-scope references attempt to exclude them
- Recognize when a perspective's scope spans too many other perspectives' domains
- Provide layered boundary recommendations that clarify responsibilities across multiple perspectives
- Check bonus/penalty criteria for cross-perspective conflicts

#### Anti-patterns
- Trusting out-of-scope references without verifying actual scope boundaries
- Only checking against perspective names without detailed scope comparison
- Providing simple "remove overlap" advice without considering multi-perspective coordination
- Missing bonus/penalty criteria boundary issues
- Not distinguishing between fatal design flaws and improvable boundary issues

---

## Summary

- **Total Scenarios**: 7
- **Difficulty Distribution**: Easy: 1, Medium: 3, Hard: 3
- **Category Coverage**:
  - Contribution Analysis: T01, T04
  - Boundary Verification: T02, T07
  - Cross-reference Validation: T03, T07
  - Actionability Assessment: T06
  - Scope Focus Evaluation: T05
