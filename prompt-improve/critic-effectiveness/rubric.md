# Evaluation Rubric: critic-effectiveness

This document consolidates the scoring criteria for all test scenarios.

---

## T01: Well-Defined Specialized Perspective (Easy)

**Category**: Value Assessment
**Total Possible Score**: 6.0 points

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T01-C1 | Value Recognition | Identifies 3+ specific accessibility issues that would be missed without this perspective (e.g., keyboard traps, missing ARIA labels, contrast failures) | Identifies 1-2 issues but lacks specificity or concrete examples | Cannot enumerate specific missed issues | 1.0 |
| T01-C2 | Actionability Confirmation | Confirms that all recommendations are actionable (WCAG references, specific HTML/CSS fixes) and not vague warnings | Notes general actionability but doesn't verify specific examples | Overlooks actionability or makes incorrect claims | 1.0 |
| T01-C3 | Boundary Clarity | Confirms the out-of-scope section correctly delegates to other perspectives without overlap | Mentions boundary but doesn't verify all delegations | Misses boundary analysis | 0.5 |
| T01-C4 | Bonus/Penalty Appropriateness | Evaluates whether bonus/penalty criteria align with the perspective's core focus | Makes superficial comment on criteria | Doesn't address criteria | 0.5 |

### Expected Key Behaviors
- Enumerate at least 3 concrete accessibility issues that would be missed (keyboard traps, missing alt text, contrast violations)
- Confirm that recommendations reference specific standards (WCAG 2.1)
- Verify that out-of-scope delegations are accurate
- Recognize that bonus/penalty criteria are well-aligned with accessibility domain

### Anti-patterns
- Cannot provide concrete examples of missed issues
- Claims the perspective overlaps with "usability" without distinguishing accessibility-specific concerns
- Overlooks the specificity of scoring criteria
- Confuses accessibility domain with general design quality

---

## T02: Perspective with Scope Overlap (Medium)

**Category**: Boundary Analysis
**Total Possible Score**: 7.0 points

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T02-C1 | Scope Overlap Detection | Identifies that "Naming Conventions" and "Code Organization" overlap with consistency, and "Testing Strategy" overlaps with reliability | Identifies 1-2 overlaps but misses others | Doesn't detect overlaps or makes incorrect claims | 1.0 |
| T02-C2 | Specific Overlap Evidence | Provides specific examples of which scope items conflict (e.g., "Naming Conventions" is part of consistency's code convention evaluation) | Mentions overlaps without specific evidence | No evidence provided | 1.0 |
| T02-C3 | Out-of-Scope Accuracy | Verifies that delegations to security, performance, structural-quality are accurate | Partially verifies delegations | Doesn't verify delegations | 0.5 |
| T02-C4 | Severity Assessment | Judges whether the overlaps are fundamental design flaws requiring perspective redesign or minor refinements | Makes general statement about severity | No severity assessment | 1.0 |

### Expected Key Behaviors
- Detect that naming conventions, code organization, and testing strategy overlap with existing perspectives
- Reference specific existing perspective scopes when identifying overlaps (e.g., "consistency already covers naming conventions")
- Distinguish between minor and major overlaps
- Recommend redesign or scope refinement based on overlap severity

### Anti-patterns
- Claims no overlaps exist when multiple are present
- Identifies overlaps that don't actually exist
- Doesn't assess the severity of overlaps
- Accepts the perspective as-is despite significant overlap issues

---

## T03: Perspective with Vague Value Proposition (Medium)

**Category**: Value Assessment, Problem Identification
**Total Possible Score**: 9.0 points

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T03-C1 | Vagueness Detection | Identifies that all 5 scope items are vague and unmeasurable (elegance, future-proofing, holistic quality, best practices, sustainability lack concrete criteria) | Identifies 2-4 vague items | Identifies 0-1 or claims scope is clear | 1.0 |
| T03-C2 | Missed Issues Enumeration | Recognizes inability to enumerate 3+ specific problems that would be missed without this perspective (due to vagueness) | Notes difficulty in enumeration but doesn't emphasize the fundamental issue | Claims specific issues can be enumerated | 1.0 |
| T03-C3 | Actionability Critique | Identifies that bonus/penalty criteria don't lead to actionable improvements ("注意すべき" pattern - recognition without action) | Mentions actionability concern but doesn't emphasize severity | Accepts criteria as actionable | 1.0 |
| T03-C4 | Scope Redundancy | Recognizes that vague scope items overlap with existing perspectives (e.g., sustainability→reliability, best practices→structural-quality) | Identifies 1-2 redundancies | Doesn't identify redundancies | 0.5 |
| T03-C5 | Redesign Necessity | Concludes that the perspective requires fundamental redesign due to lack of value proposition | Suggests improvements but doesn't call for redesign | Accepts the perspective with minor changes | 1.0 |

### Expected Key Behaviors
- Identify that all scope items are subjective and lack measurable criteria
- Recognize inability to enumerate concrete missed issues
- Flag that scoring criteria promote vague observations rather than actionable recommendations
- Recommend fundamental redesign due to lack of clear value proposition
- Distinguish this from perspectives with minor issues

### Anti-patterns
- Accepts vague terms like "elegance" and "holistic quality" as sufficient
- Claims concrete problems can be identified from these vague criteria
- Suggests minor wording changes instead of fundamental redesign
- Confuses "sounds important" with "provides specific value"

---

## T04: Perspective with Inaccurate Cross-References (Medium)

**Category**: Boundary Analysis, Cross-reference Validation
**Total Possible Score**: 7.0 points

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T04-C1 | Incorrect Reference Detection | Identifies that "Database transaction handling → reliability" and "API documentation completeness → structural-quality" are inaccurate (reliability covers fault tolerance but not transaction handling; structural-quality covers design patterns but not documentation) | Identifies 1 incorrect reference | Doesn't identify incorrect references or makes incorrect claims | 1.0 |
| T04-C2 | Missing Scope Item | Identifies that "Error Response Design" (in scope) overlaps with "Error recovery" in reliability perspective, but isn't acknowledged in out-of-scope section | Notes potential overlap but doesn't identify the specific missing delegation | Doesn't identify the missing delegation | 1.0 |
| T04-C3 | Accurate Reference Verification | Confirms that "Authentication/Authorization → security" and "Rate limiting → performance" are accurate | Partially verifies references | Doesn't verify accurate references | 0.5 |
| T04-C4 | Correction Recommendation | Recommends specific corrections to the out-of-scope section (remove or correct inaccurate references, add missing delegation for error response design) | Makes general recommendation without specifics | Doesn't recommend corrections | 1.0 |

### Expected Key Behaviors
- Identify at least 2 inaccurate cross-references by comparing scope items to existing perspective summaries
- Distinguish between accurate references (auth→security, rate limiting→performance) and inaccurate ones
- Note missing delegation for error response design (overlaps with reliability)
- Provide specific corrections to improve boundary clarity

### Anti-patterns
- Claims all cross-references are accurate when inaccuracies exist
- Identifies issues that don't exist (false positives)
- Doesn't verify references against existing perspective summaries
- Makes vague comments about "checking references" without specific findings

---

## T05: Minimal Edge Case - Extremely Narrow Perspective (Hard)

**Category**: Value Assessment, Cross-reference Validation
**Total Possible Score**: 9.0 points

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T05-C1 | Excessive Narrowness Detection | Identifies that the scope is too narrow (HTTP status codes alone don't justify a full perspective) and should be part of a broader API design or consistency perspective | Notes narrowness but doesn't recommend integration | Doesn't detect narrowness issue | 1.0 |
| T05-C2 | Limited Value Assessment | Recognizes that while status code correctness is important, it doesn't warrant a dedicated critique agent (issues are typically caught by linters or API guidelines) | Acknowledges limited scope but doesn't assess value proposition | Claims sufficient value despite narrowness | 1.0 |
| T05-C3 | False Out-of-Scope Detection | Identifies that "API endpoint design → (no existing perspective covers this)" is incorrect notation (should reference a specific perspective or state "not covered by existing perspectives") | Notes odd notation but doesn't identify the issue clearly | Doesn't detect the notation error | 0.5 |
| T05-C4 | Integration Recommendation | Recommends merging this perspective into "consistency" or creating a broader "API Design Quality" perspective that includes status codes as one component | Suggests integration but doesn't specify target | Accepts as standalone perspective | 1.0 |
| T05-C5 | Enumeration Challenge | Recognizes that while 3+ problems can technically be enumerated (wrong 2xx/4xx/5xx codes), these are mechanical checks rather than insight-requiring analysis | Enumerates problems but doesn't assess their nature | Claims sufficient missed issues without qualification | 1.0 |

### Expected Key Behaviors
- Identify that the scope is too narrow for a dedicated perspective
- Assess that mechanical checks (status code correctness) provide limited value compared to automated tools
- Detect the incorrect notation in out-of-scope section
- Recommend integration into a broader perspective (consistency or API design)
- Distinguish between "can enumerate issues" and "provides meaningful analytical value"

### Anti-patterns
- Accepts the narrow scope as sufficient for a standalone perspective
- Claims that status code correctness alone justifies a critique agent
- Overlooks the false out-of-scope notation
- Treats all enumerable issues as equally valuable regardless of mechanical vs. analytical nature

---

## T06: Complex Overlap - Partially Redundant Perspective (Hard)

**Category**: Boundary Analysis, Cross-reference Validation
**Total Possible Score**: 9.0 points

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T06-C1 | Major Overlap Detection | Identifies that 4 of 5 scope items overlap with reliability perspective: failure mode analysis (fault tolerance), circuit breakers (fallback strategies), retry strategies (retry mechanisms), data consistency (data consistency) | Identifies 2-3 overlapping items | Identifies 0-1 overlapping items | 1.0 |
| T06-C2 | Distinguishing Partial Overlap | Recognizes that "Monitoring and Alerting" may not fully overlap with reliability (operational concerns vs. design-time fault tolerance), requiring clarification of scope boundaries | Notes monitoring as potentially distinct but doesn't analyze depth | Doesn't distinguish partial vs. full overlap | 1.0 |
| T06-C3 | Terminology Redundancy | Identifies that "System Resilience" and existing "reliability" perspective are near-synonyms, suggesting renaming or merging | Notes similarity but doesn't address terminology conflict | Doesn't recognize terminology redundancy | 0.5 |
| T06-C4 | Out-of-Scope Incompleteness | Identifies that the out-of-scope section should acknowledge reliability perspective for the 4 overlapping items | Mentions missing reference but doesn't specify items | Doesn't identify incompleteness | 1.0 |
| T06-C5 | Redesign vs. Merge Decision | Evaluates whether this perspective should be: (a) merged into reliability, (b) focused only on monitoring/operations, or (c) redesigned to focus on aspects not covered by reliability | Suggests one option without evaluation | Doesn't provide clear recommendation | 1.0 |

### Expected Key Behaviors
- Identify 4 of 5 scope items that directly overlap with reliability perspective
- Distinguish monitoring/alerting as potentially distinct operational concern
- Note that "resilience" and "reliability" are near-synonyms, causing confusion
- Recognize that out-of-scope section doesn't acknowledge reliability perspective
- Recommend either merge or significant redesign to eliminate redundancy

### Anti-patterns
- Claims no significant overlap with reliability perspective
- Accepts all 5 items as distinct from reliability without analysis
- Doesn't address terminology redundancy between "resilience" and "reliability"
- Suggests minor tweaks instead of fundamental redesign/merge
- Overlooks the missing reliability reference in out-of-scope section

---

## T07: Perspective with Non-Actionable Outputs (Hard)

**Category**: Actionability Evaluation, Value Assessment
**Total Possible Score**: 10.0 points

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T07-C1 | Recognition-Only Pattern Detection | Identifies that all bonus criteria reward "recognition," "acknowledgment," and "highlighting" without requiring specific improvements (classic "注意すべき" pattern) | Notes that criteria focus on recognition but doesn't emphasize the actionability gap | Doesn't detect the recognition-only pattern | 1.0 |
| T07-C2 | Actionability Failure Analysis | Analyzes that the perspective doesn't generate actionable outputs (finding "debt is acknowledged" doesn't provide improvement path; finding "debt is not acknowledged" only states the obvious) | Notes limited actionability but doesn't analyze why | Accepts outputs as actionable | 1.0 |
| T07-C3 | Scope Ambiguity | Identifies that all 5 scope items are subjective and lack measurable criteria (what constitutes "adequate" documentation, "sufficient" justification, or "appropriate" prioritization?) | Notes some ambiguity but doesn't emphasize scope-wide issue | Accepts scope as sufficiently clear | 1.0 |
| T07-C4 | Value Proposition Weakness | Recognizes that the perspective's value is limited because: (1) it doesn't identify specific debt, (2) it doesn't recommend debt reduction strategies, (3) it only evaluates meta-information (documentation of debt, not debt itself) | Notes limited value but doesn't provide structured reasoning | Claims sufficient value proposition | 1.0 |
| T07-C5 | Fundamental Redesign Necessity | Concludes that the perspective requires fundamental redesign to focus on identifying actual technical debt (code smells, anti-patterns, design compromises) rather than evaluating documentation of debt | Suggests improvements but doesn't call for redesign | Accepts the perspective with minor modifications | 1.0 |

### Expected Key Behaviors
- Identify that all scoring criteria reward recognition/acknowledgment rather than actionable improvements
- Analyze why outputs would not be actionable (meta-evaluation doesn't lead to concrete fixes)
- Detect ambiguity in all 5 scope items (lack of measurable criteria)
- Assess limited value proposition (evaluating documentation of debt vs. identifying actual debt)
- Recommend fundamental redesign to focus on concrete technical debt identification

### Anti-patterns
- Claims that recognizing documented debt is a valuable review output
- Accepts "highlighting well-justified trade-offs" as actionable feedback
- Overlooks the distinction between evaluating debt documentation and identifying actual debt
- Suggests minor wording changes instead of fundamental purpose redesign
- Doesn't recognize the "注意すべき" anti-pattern across all criteria

---

## Scoring Summary

| Scenario | Difficulty | Total Points | Primary Capabilities Tested |
|----------|-----------|--------------|----------------------------|
| T01 | Easy | 6.0 | Value Recognition, Actionability Confirmation |
| T02 | Medium | 7.0 | Scope Overlap Detection, Severity Assessment |
| T03 | Medium | 9.0 | Vagueness Detection, Redesign Necessity |
| T04 | Medium | 7.0 | Incorrect Reference Detection, Correction Recommendation |
| T05 | Hard | 9.0 | Excessive Narrowness Detection, Integration Recommendation |
| T06 | Hard | 9.0 | Major Overlap Detection, Redesign vs. Merge Decision |
| T07 | Hard | 10.0 | Recognition-Only Pattern Detection, Actionability Failure Analysis |

**Total Possible Score**: 57.0 points

**Difficulty Distribution**:
- Easy: 1 scenario (6.0 points)
- Medium: 3 scenarios (23.0 points)
- Hard: 3 scenarios (28.0 points)

**Capability Coverage**:
- Value Assessment: T01, T03, T05, T07 (34.0 points)
- Boundary Analysis: T02, T04, T06 (23.0 points)
- Cross-reference Validation: T04, T05, T06 (25.0 points)
- Problem Identification: T01, T03 (15.0 points)
- Actionability Evaluation: T01, T03, T07 (26.0 points)
