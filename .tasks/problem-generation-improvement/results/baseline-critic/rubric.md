# Scoring Rubric for critic-effectiveness Test Scenarios

## T01: Missing Contribution Evidence

### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T01-C1 | Contribution identification | Identifies 3+ specific problems that would be missed without this perspective, with concrete examples | Identifies 1-2 problems or examples lack specificity | Does not identify missed problems or examples are too vague | 1.0 |
| T01-C2 | Actionability verification | Verifies that each identified problem leads to concrete, fixable improvements (not just "be aware of") | Mentions actionability but verification is incomplete | Does not verify actionability | 1.0 |
| T01-C3 | Scope focus assessment | Assesses whether the 5 scope items are appropriately focused and not too broad/narrow | Mentions scope focus but assessment is superficial | Does not assess scope focus | 0.5 |

### Expected Key Behaviors
- Identify concrete examples like "Missing API endpoint parameters" or "Outdated version references"
- Verify that findings lead to actionable fixes (e.g., "Add parameter documentation" not just "Improve docs")
- Assess whether scope covers a coherent set of related concerns

### Anti-patterns
- Accepting vague contribution claims without concrete examples
- Not verifying whether identified problems lead to specific improvements
- Ignoring scope focus evaluation

---

## T02: Scope Overlap Detection

### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T02-C1 | Overlap detection with Security | Identifies that "Input validation errors" overlaps with Security's "Input validation" scope item and provides specific evidence | Mentions overlap but evidence is incomplete or vague | Does not detect the overlap | 1.0 |
| T02-C2 | Overlap detection with Reliability | Identifies that "Retry logic" and "Fallback mechanism" overlap with Reliability's "error recovery", "failover", and "graceful degradation" scope items with specific evidence | Mentions overlap but evidence is incomplete | Does not detect the overlap | 1.0 |
| T02-C3 | Boundary recommendation | Recommends clear boundary definition (e.g., limit to "application-level business logic errors" and exclude security/infrastructure errors) | Mentions need for boundary clarification but recommendation lacks specificity | Does not recommend boundary clarification | 1.0 |
| T02-C4 | Penalty scoring overlap detection | Identifies that the penalty "Exposing sensitive information in errors" overlaps with Security perspective | Mentions the penalty issue but analysis is incomplete | Does not identify the penalty overlap | 0.5 |

### Expected Key Behaviors
- Compare each of the 5 scope items against existing perspectives' scope systematically
- Provide specific evidence of overlap (e.g., "Item 4 'Input validation errors' duplicates Security's 'Input validation'")
- Recommend explicit scope boundaries to prevent overlap
- Check bonus/penalty criteria for cross-perspective conflicts

### Anti-patterns
- Only checking perspective names without comparing specific scope items
- Declaring "no overlap" without systematic comparison
- Ignoring bonus/penalty criteria when checking boundaries

---

## T03: Accurate Cross-Reference Validation

### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T03-C1 | Valid reference detection | Identifies that "API response time → Performance" and "Database query optimization → Performance" are valid references (Performance includes these) | Identifies only 1 valid reference or verification is incomplete | Does not verify valid references | 1.0 |
| T03-C2 | Invalid reference detection | Identifies that "Rate limiting configuration → Security" is invalid (Security perspective does not include rate limiting, which is typically a Performance/Availability concern) | Mentions the reference issue but analysis is incomplete | Does not detect the invalid reference | 1.0 |
| T03-C3 | Reference correction recommendation | Recommends correcting "Rate limiting" reference to Performance or Reliability perspective | Mentions need for correction but recommendation is vague | Does not recommend correction | 0.5 |

### Expected Key Behaviors
- Cross-check each out-of-scope reference against the existing perspectives summary
- Verify that referenced perspectives actually include the delegated scope
- Identify mismatched references and recommend correct perspective assignment
- Distinguish between valid and invalid cross-references

### Anti-patterns
- Assuming all references are correct without verification
- Not checking whether referenced perspectives actually cover the delegated items
- Failing to recommend alternative references when delegation is incorrect

---

## T04: Vague Value Proposition

### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T04-C1 | Vague scope detection | Identifies that scope items like "Architectural decisions appropriateness", "Component interaction clarity", and "Maintainability factors" are too vague and overlap with multiple existing perspectives | Mentions vagueness but analysis is incomplete | Does not detect vague scope items | 1.0 |
| T04-C2 | Overlap with existing perspectives | Identifies that "Design pattern usage" duplicates Code Quality's scope, "System scalability" duplicates Performance's scope, and "Maintainability factors" duplicates Maintainability perspective | Identifies 1-2 overlaps but misses others | Does not identify overlaps | 1.0 |
| T04-C3 | Critical issue classification | Classifies this as a "Critical Issue" requiring fundamental redesign because the perspective lacks clear unique contribution | Mentions problems but does not classify as critical | Does not recognize the severity | 1.0 |
| T04-C4 | Specific improvement recommendation | Recommends either (1) narrowing focus to specific architectural aspects not covered elsewhere, or (2) deprecating this perspective in favor of existing ones | Mentions need for change but recommendation lacks specificity | Does not provide actionable recommendation | 0.5 |

### Expected Key Behaviors
- Identify when scope items are too broad/vague to provide clear evaluation criteria
- Detect systematic overlap with multiple existing perspectives
- Escalate to "Critical Issue" when perspective lacks unique value
- Recommend specific focus areas or perspective consolidation

### Anti-patterns
- Accepting vague scope items without questioning their evaluability
- Not comparing against multiple existing perspectives systematically
- Downplaying fundamental design issues as minor improvements
- Providing generic recommendations without specific focus areas

---

## T05: Overly Narrow Scope

### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T05-C1 | Narrow scope detection | Identifies that this perspective is overly narrow, focusing only on GraphQL mutations when naming consistency should be evaluated more broadly | Mentions narrowness but analysis lacks depth | Does not detect the overly narrow scope | 1.0 |
| T05-C2 | Overlap with existing perspectives | Identifies that naming consistency is already covered by "Consistency" perspective and code naming by "Code Quality" perspective | Mentions overlap with 1 perspective but misses the other | Does not identify the overlap | 1.0 |
| T05-C3 | Consolidation recommendation | Recommends consolidating this into the existing Consistency or API Design perspective as a sub-criterion rather than maintaining a separate perspective | Mentions consolidation but recommendation is vague | Does not recommend consolidation | 1.0 |
| T05-C4 | Cost-benefit analysis | Analyzes that maintaining a separate perspective for this narrow scope has low value compared to integration into broader perspective | Mentions value concern but analysis is incomplete | Does not perform cost-benefit analysis | 0.5 |

### Expected Key Behaviors
- Recognize when a perspective's scope is too narrow to justify separate evaluation
- Check if the narrow scope is already covered by existing broader perspectives
- Recommend consolidation into existing perspectives as sub-criteria
- Consider maintenance cost vs. evaluation value

### Anti-patterns
- Accepting narrow scope without questioning its necessity as separate perspective
- Not checking if broader perspectives already cover the narrow scope
- Recommending creation of multiple narrow perspectives instead of consolidation
- Ignoring the practical overhead of maintaining too many perspectives

---

## T06: Missing Actionability Verification

### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T06-C1 | Non-actionable output pattern detection | Identifies that scope items use "awareness", "perception", "understanding", "knowledge" which lead to recognition-only outputs rather than concrete improvements | Identifies some awareness language but analysis is incomplete | Does not detect the non-actionable pattern | 1.0 |
| T06-C2 | Bonus/penalty actionability analysis | Identifies that bonus "Demonstrates awareness" and penalty "Shows no consideration" evaluate mindset rather than concrete, fixable issues | Mentions the issue but analysis lacks depth | Does not analyze bonus/penalty actionability | 1.0 |
| T06-C3 | Critical issue classification | Classifies this as a "Critical Issue" because the perspective fundamentally cannot lead to actionable improvements - it evaluates awareness rather than concrete changes | Mentions problems but does not classify as critical | Does not recognize the fundamental flaw | 1.0 |
| T06-C4 | Concrete reformulation recommendation | Recommends reformulating scope to concrete, measurable criteria (e.g., "Variable names follow domain terminology", "Functions under 20 lines", "Public APIs have documentation") | Mentions need for concrete criteria but examples are vague | Does not provide specific reformulation guidance | 0.5 |

### Expected Key Behaviors
- Detect when evaluation criteria focus on "awareness" or "understanding" rather than concrete artifacts
- Verify that identified problems can lead to specific, implementable fixes
- Distinguish between "recognize the issue" and "fix the issue" outcomes
- Recommend transformation to concrete, measurable criteria

### Anti-patterns
- Accepting "awareness" or "consideration" as valid evaluation outcomes
- Not checking whether perspective outputs lead to actionable fixes
- Confusing "identifying a problem" with "having a fixable problem"
- Providing generic advice like "be more specific" without concrete examples

---

## T07: Complex Multi-Perspective Boundary Issue

### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T07-C1 | Security overlap detection | Identifies that "API-level request validation" and "Database constraint validation" overlap with Security's "Input validation for security" despite the out-of-scope reference attempt | Identifies overlap with 1 item or evidence is incomplete | Does not detect Security overlap | 1.0 |
| T07-C2 | Error Handling overlap detection | Identifies that "Error response handling for validation failures" completely duplicates Error Handling perspective's "Input validation errors" scope item | Mentions overlap but does not recognize complete duplication | Does not detect Error Handling overlap | 1.0 |
| T07-C3 | Code Quality overlap detection | Identifies that "Business rule validation logic" overlaps with Code Quality's "validation logic organization" and "error handling patterns" | Mentions overlap but analysis is incomplete | Does not detect Code Quality overlap | 0.5 |
| T07-C4 | Multi-perspective boundary recommendation | Recommends clear layered boundaries: distinguish between (1) security-focused validation (→Security), (2) business logic validation (this perspective), (3) error handling patterns (→Error Handling), and (4) implementation quality (→Code Quality) | Mentions need for boundaries but recommendation lacks layered clarity | Does not provide multi-perspective boundary solution | 1.0 |
| T07-C5 | Bonus criteria boundary issue | Identifies that bonus "User-friendly validation error messages" overlaps with Error Handling's scope, and "Centralized validation rule management" overlaps with Code Quality's organizational concerns | Identifies 1 bonus overlap but misses the other | Does not identify bonus overlaps | 0.5 |
| T07-C6 | Critical vs improvement classification | Correctly classifies this as either "Critical Issue" (requiring fundamental redesign to separate concerns) or "Improvement Suggestion" with very specific boundary definitions - with clear rationale | Provides classification but rationale is weak | Does not provide appropriate classification | 0.5 |

### Expected Key Behaviors
- Systematically check each scope item against multiple existing perspectives
- Identify overlaps even when out-of-scope references attempt to exclude them
- Recognize when a perspective's scope spans too many other perspectives' domains
- Provide layered boundary recommendations that clarify responsibilities across multiple perspectives
- Check bonus/penalty criteria for cross-perspective conflicts

### Anti-patterns
- Trusting out-of-scope references without verifying actual scope boundaries
- Only checking against perspective names without detailed scope comparison
- Providing simple "remove overlap" advice without considering multi-perspective coordination
- Missing bonus/penalty criteria boundary issues
- Not distinguishing between fatal design flaws and improvable boundary issues

---

## Scoring Summary

| Scenario | Criteria Count | Total Weight | Max Score |
|----------|---------------|--------------|-----------|
| T01 | 3 | 2.5 | 5.0 |
| T02 | 4 | 3.5 | 7.0 |
| T03 | 3 | 2.5 | 5.0 |
| T04 | 4 | 3.5 | 7.0 |
| T05 | 4 | 3.5 | 7.0 |
| T06 | 4 | 3.5 | 7.0 |
| T07 | 6 | 4.5 | 9.0 |
| **Total** | **28** | **23.5** | **47.0** |

## Normalization

All scenario scores will be normalized to a 0-10 scale for comparison purposes:
- Individual scenario score = (Achieved points / Max scenario points) × 10
- Overall test suite score = (Total achieved points / 47.0) × 10
