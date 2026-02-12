# Scoring Rubric: critic-effectiveness

**Agent**: critic-effectiveness
**Type**: Type-C (Meta-evaluation Agent)
**Generated**: 2026-02-12

---

## Scoring Methodology

```
scenario_score = (Σ(rating × weight) + bonus - penalty) / max_possible × 10
rating: ○=2, △=1, ×=0
```

**Example Calculation for T01**:
- 3 answer keys, each weight=1.0, max_possible = 3×2 = 6
- If ratings are: ○(2), △(1), ○(2), bonus=+1.0, penalty=-0.5
- Raw score = (2 + 1 + 2 + 1.0 - 0.5) / 6 = 5.5 / 6 = 0.917
- Scenario score = 0.917 × 10 = **9.17/10**

---

## Problem Bank

### Value Recognition (9 problems)

#### PB-01: Vague Value Proposition [Medium]
**Description**: Purpose statement is too generic and doesn't specify what unique problems this perspective detects.
- **○ (Full)**: Points out the vagueness and suggests adding concrete examples of problems this perspective uniquely catches.
- **△ (Partial)**: Notes the vagueness but doesn't provide specific improvement direction (e.g., what examples to add).
- **× (Miss)**: Doesn't mention the vague value proposition or considers it acceptable.

#### PB-04: Excessive Narrowness [High]
**Description**: Perspective scope is so narrow that it provides minimal value (e.g., only covering trivial or automatable checks).
- **○ (Full)**: Identifies the excessive narrowness and assesses whether this provides sufficient value. Suggests expansion or consolidation with other perspectives.
- **△ (Partial)**: Notes the perspective is narrow but doesn't assess value impact or suggest remediation.
- **× (Miss)**: Doesn't identify the narrowness issue.

#### PB-05: Low Actionability - Automated Tool Domain [High]
**Description**: All scope items are automatically handled by linters/formatters, questioning the value of manual review.
- **○ (Full)**: Points out that scope items are auto-fixable and questions the perspective's value given automation. Notes contradictions with penalty guidelines if present.
- **△ (Partial)**: Mentions automation availability but doesn't question the perspective's value or note contradictions.
- **× (Miss)**: Doesn't identify the low actionability issue.

#### PB-19: Value Proposition Strength - Concrete Examples [Medium]
**Description**: Evaluating whether a well-defined perspective has strong value proposition with concrete examples.
- **○ (Full)**: Affirms value proposition strength by analyzing what problems would be missed without this perspective and verifying actionability of fixes.
- **△ (Partial)**: Acknowledges examples but doesn't analyze problem coverage or actionability.
- **× (Miss)**: Doesn't evaluate value proposition.

#### PB-22: Non-Actionable Output Pattern - "Should Follow" [High]
**Description**: Scope consists of abstract principles without concrete detection criteria, leading to vague "should follow X principle" outputs.
- **○ (Full)**: Identifies the actionability risk from abstract principles and suggests concrete detection criteria (e.g., metrics, thresholds, patterns).
- **△ (Partial)**: Notes the abstract nature but doesn't identify actionability risk or suggest concrete criteria.
- **× (Miss)**: Doesn't detect the non-actionable output pattern risk.

#### PB-23: Massive Overlap with Multiple Perspectives [High]
**Description**: Perspective duplicates scope from many other perspectives, questioning its need to exist.
- **○ (Full)**: Identifies systemic overlap across multiple perspectives and questions whether the perspective should exist vs. being distributed to specialized perspectives.
- **△ (Partial)**: Notes some overlaps but doesn't identify systemic duplication or question the perspective's existence.
- **× (Miss)**: Doesn't detect the massive overlap issue.

#### PB-27: Domain-Specific Perspective - Limited Applicability [Medium]
**Description**: Perspective is only applicable to specific domains (e.g., cloud infrastructure, not application code).
- **○ (Full)**: Questions applicability breadth and suggests clarifying scope (e.g., renaming to indicate specialization or noting limited activation scenarios).
- **△ (Partial)**: Notes domain focus but doesn't question applicability or suggest clarification.
- **× (Miss)**: Doesn't detect the limited applicability issue.

#### PB-02: Overlapping Scope with Other Perspectives [Medium]
**Description**: Scope item overlaps with potential other perspectives without clear boundary.
- **○ (Full)**: Identifies the overlap and suggests clarifying the boundary by specifying the angle/lens this perspective uses (e.g., "from security perspective" vs. "from reliability perspective").
- **△ (Partial)**: Notes potential overlap but doesn't specify which perspective or doesn't suggest boundary clarification.
- **× (Miss)**: Doesn't detect the scope overlap.

#### PB-06: Missing Critical Differentiation from Related Perspective [Medium]
**Description**: Unclear boundary with a closely related perspective, creating potential redundancy or gaps.
- **○ (Full)**: Identifies unclear differentiation and suggests concrete boundary definition (e.g., what each perspective covers, where they differ).
- **△ (Partial)**: Notes the related perspective but doesn't question boundary clarity or redundancy.
- **× (Miss)**: Doesn't detect the differentiation issue.

---

### Boundary Clarity (12 problems)

#### PB-02: Overlapping Scope with Other Perspectives [Medium]
(See Value Recognition section - this problem tests both categories)

#### PB-03: Circular Reference in Out-of-Scope [High]
**Description**: Out-of-scope delegation creates circular dependency (e.g., delegating a core aspect of the perspective's purpose to another perspective).
- **○ (Full)**: Identifies the circular dependency and suggests resolution (e.g., keeping certain aspects in-scope or clarifying the delegation boundary).
- **△ (Partial)**: Notices the delegation but doesn't identify circularity or suggest resolution.
- **× (Miss)**: Doesn't detect the circular reference.

#### PB-06: Missing Critical Differentiation from Related Perspective [Medium]
(See Value Recognition section - this problem tests both categories)

#### PB-07: Overlapping Algorithmic Complexity with Code Quality [Medium]
**Description**: Scope item (algorithmic complexity) can be viewed from multiple perspectives (runtime performance vs. cognitive complexity).
- **○ (Full)**: Identifies the multi-dimensional nature and suggests clarifying the boundary by limiting to specific angle (e.g., "runtime complexity" vs. "cognitive complexity").
- **△ (Partial)**: Notes potential overlap but doesn't specify the dimension or suggest boundary clarification.
- **× (Miss)**: Doesn't detect the overlap.

#### PB-08: Ambiguous Caching Scope Boundary [Medium]
**Description**: Scope item (caching) has unclear boundary with another perspective (Data Architecture).
- **○ (Full)**: Identifies the boundary ambiguity with concrete examples (e.g., where does cache strategy end and data architecture begin?) and suggests clarification with examples.
- **△ (Partial)**: Notes the item but doesn't identify boundary ambiguity.
- **× (Miss)**: Doesn't detect the issue.

#### PB-10: Database Schema Delegation Boundary Issue [Medium]
**Description**: Delegated item (database schema) has aspects directly relevant to this perspective's scope.
- **○ (Full)**: Identifies that delegated item impacts this perspective's domain and suggests clarifying that this perspective can comment on relevant aspects (e.g., "performance implications of schema") while delegation handles other aspects (e.g., "schema structure").
- **△ (Partial)**: Notes the delegation but doesn't identify the overlap with this perspective's domain.
- **× (Miss)**: Doesn't detect the boundary issue.

#### PB-12: Monitoring Scope Overlap with Operations [Medium]
**Description**: In-scope item (monitoring/observability) overlaps with delegated item (logging infrastructure).
- **○ (Full)**: Points out the overlap (logging IS part of observability) and suggests clarifying boundary (e.g., "what to monitor" vs. "how to implement monitoring infrastructure").
- **△ (Partial)**: Notes the items but doesn't identify overlap.
- **× (Miss)**: Doesn't detect the overlap.

#### PB-15: Unverified Cross-Reference - Testing Perspective [Medium]
**Description**: Delegation to a perspective that may not exist or may not cover the delegated item.
- **○ (Full)**: Identifies unverified cross-reference and suggests adding verification note (e.g., "if Testing perspective exists") or checking that delegated item is actually covered.
- **△ (Partial)**: Notes the delegation but doesn't question whether the referenced perspective exists or covers the item.
- **× (Miss)**: Doesn't detect the unverified reference.

#### PB-16: Boundary Ambiguity with Design Patterns and Performance [Medium]
**Description**: Scope item (design patterns) can be evaluated from multiple perspectives.
- **○ (Full)**: Identifies that design patterns have multi-dimensional concerns (e.g., testability/modularity vs. runtime efficiency) and suggests clarifying the evaluation lens.
- △ (Partial)**: Notes the item but doesn't identify potential overlap or multi-dimensional nature.
- **× (Miss)**: Doesn't detect the boundary ambiguity.

#### PB-18: Subtle Overlap - Naming Consistency vs Code Style [Low]
**Description**: Subtle boundary case where scope item could be interpreted as belonging to another perspective.
- **○ (Full)**: Identifies the subtle boundary and examines whether clarification is needed (e.g., cross-module consistency vs. within-file formatting). May also note that existing scope definitions already clarify the boundary.
- **△ (Partial)**: Notes the item but doesn't examine the subtle boundary.
- **× (Miss)**: Doesn't detect the potential overlap.

#### PB-21: Architectural Pattern Consistency - Scope Boundary [Medium]
**Description**: Scope item (architectural pattern consistency) may overlap with System Architecture perspective.
- **○ (Full)**: Notes potential overlap with architectural concerns and suggests boundary clarification (e.g., "inconsistent application of patterns" vs. "pattern selection and justification").
- **△ (Partial)**: Notes the item but doesn't question potential overlap or propose boundary.
- **× (Miss)**: Doesn't detect the scope boundary issue.

#### PB-26: Scope Boundary - Performance Overlap Complex [High]
**Description**: Complex circular dependency where cost-performance tradeoffs create mutual dependency between perspectives.
- **○ (Full)**: Identifies the circular dependency (cost optimization impacts performance, performance analysis requires cost context) and suggests resolution (e.g., clarifying mention vs. detailed analysis, or defining joint responsibility).
- **△ (Partial)**: Notes the delegation but doesn't identify circular dependency or complexity.
- **× (Miss)**: Doesn't detect the scope boundary issue.

---

### Scope Assessment (6 problems)

#### PB-04: Excessive Narrowness [High]
(See Value Recognition section - this problem tests both categories)

#### PB-11: Contradictory Out-of-Scope - Security Error Responses [High]
**Description**: Out-of-scope delegation contradicts in-scope item (delegating error response security to Security, but error responses ARE error handling which is in-scope).
- **○ (Full)**: Identifies the contradiction and circular dependency. Suggests keeping relevant aspects in-scope (e.g., "error response content") and only delegating specific concerns (e.g., "authentication/authorization errors").
- **△ (Partial)**: Notes the delegation but doesn't identify contradiction or circular dependency.
- **× (Miss)**: Doesn't detect the issue.

#### PB-13: Data Consistency Out of Place [Medium]
**Description**: Scope item may belong in a different perspective (e.g., data consistency in distributed systems could be Data Architecture vs. Reliability).
- **○ (Full)**: Questions whether the item belongs in this perspective and suggests clarifying to specific angle (e.g., "consistency during failures" for Reliability vs. "consistency models" for Data Architecture).
- **△ (Partial)**: Notes the item but doesn't question its fit or suggest clarification.
- **× (Miss)**: Doesn't detect the potential misalignment.

#### PB-17: Circular Dependency Bonus Should Be In-Scope [Low]
**Description**: Bonus item is directly related to in-scope item and should likely be promoted.
- **○ (Full)**: Questions why bonus item is not in-scope given its direct relation to an in-scope item. Suggests promoting to in-scope or explaining the bonus categorization.
- **△ (Partial)**: Notes the bonus but doesn't question why it's not in-scope.
- **× (Miss)**: Doesn't detect the misalignment.

#### PB-24: Bonus/Penalty Contradict Each Other [Medium]
**Description**: Bonus and penalty items address the same concern from different angles, creating confusion.
- **○ (Full)**: Identifies the contradiction (both address over-engineering) and suggests consolidation or clarification of when each applies.
- **△ (Partial)**: Notes similarity but doesn't identify contradiction or confusion.
- **× (Miss)**: Doesn't detect the contradiction.

#### PB-25: Recursive Bonus - "Missing SOLID Principles" [Medium]
**Description**: Bonus item duplicates in-scope expectation (detecting missing SOLID adherence is already in-scope).
- **○ (Full)**: Identifies that bonus duplicates in-scope and suggests removal or clarification (e.g., bonus for uncommon SOLID violations).
- **△ (Partial)**: Notes the bonus but doesn't identify duplication.
- **× (Miss)**: Doesn't detect the recursive bonus.

---

### Evidence Analysis (10 problems)

#### PB-09: Vague Penalty Criterion - "Measurable Impact" [Medium]
**Description**: Penalty criterion lacks concrete definition (e.g., what threshold constitutes "measurable impact"?).
- **○ (Full)**: Identifies vague criterion and suggests concrete thresholds or clarification (e.g., "improvements < 5% of total" or "concerns that cannot be quantified at all").
- **△ (Partial)**: Notes the vague penalty but doesn't suggest how to make it concrete.
- **× (Miss)**: Doesn't question the penalty criterion.

#### PB-10: Database Schema Delegation Boundary Issue [Medium]
(See Boundary Clarity section - this problem tests both categories)

#### PB-14: Penalty Assumes Knowledge Not in Scope [Medium]
**Description**: Penalty criterion assumes knowledge (e.g., idempotency) not mentioned in in-scope items.
- **○ (Full)**: Identifies the gap between penalty assumption and scope. Suggests adding the knowledge to scope or removing the penalty.
- **△ (Partial)**: Notes the penalty but doesn't identify the gap with scope.
- **× (Miss)**: Doesn't question the penalty criterion.

#### PB-16: Boundary Ambiguity with Design Patterns and Performance [Medium]
(See Boundary Clarity section - this problem tests both categories)

#### PB-19: Value Proposition Strength - Concrete Examples [Medium]
(See Value Recognition section - this problem tests both categories)

#### PB-20: Penalty Edge Case - "Documented Rationale" [Medium]
**Description**: Penalty assumes reviewer has access to information that may not be in reviewed material.
- **○ (Full)**: Questions the assumption (reviewer has access to all rationale documentation) and suggests clarification about when penalty applies (e.g., "rationale is present in reviewed material").
- **△ (Partial)**: Notes the penalty but doesn't identify the assumption or edge case.
- **× (Miss)**: Doesn't question the penalty criterion.

#### PB-22: Non-Actionable Output Pattern - "Should Follow" [High]
(See Value Recognition section - this problem tests both categories)

#### PB-28: Penalty Assumes Business Context [Medium]
**Description**: Penalty requires data (costs, usage patterns, ROI) typically not available in design documents.
- **○ (Full)**: Points out the data availability assumption and suggests clarifying when penalty applies (e.g., "when cost data is provided") or adjusting to qualitative assessment.
- **△ (Partial)**: Notes the penalty but doesn't identify the data assumption.
- **× (Miss)**: Doesn't question the penalty criterion.

#### PB-11: Contradictory Out-of-Scope - Security Error Responses [High]
(See Scope Assessment section - this problem tests both categories)

#### PB-12: Monitoring Scope Overlap with Operations [Medium]
(See Boundary Clarity section - this problem tests both categories)

---

## Answer Keys by Scenario

### T01: Generic Security Perspective (Easy)

**Max Possible**: 6 points (3 AKs × weight 1.0 × rating 2)

**AK-T01-01 (PB-01): Vague Value Proposition** [Weight: 1.0]
- ○: Points out that "Evaluate security aspects" is too generic and doesn't specify what unique problems this perspective detects (e.g., "What security issues would be missed without this perspective?"). Suggests adding concrete examples like "SQL injection, XSS, authentication bypass" to clarify contribution.
- △: Notes the vagueness but doesn't provide specific improvement direction (e.g., "The purpose is too general" without suggesting what specific security problems should be mentioned).
- ×: Doesn't mention the vague value proposition or considers it acceptable.

**AK-T01-02 (PB-02): Overlapping Scope with Other Perspectives** [Weight: 1.0]
- ○: Identifies that "Input validation and sanitization" (item 3) overlaps with potential Reliability or Data Quality perspectives. Notes that input validation errors could belong to error handling (Reliability). Suggests clarifying the boundary by specifying "Input validation from a security perspective (e.g., injection prevention)" vs. "Input validation for data integrity."
- △: Notes potential overlap with input validation but doesn't specify which other perspective or doesn't suggest how to resolve the boundary.
- ×: Doesn't detect the scope overlap issue.

**AK-T01-03 (PB-03): Circular Reference in Out-of-Scope** [Weight: 1.0]
- ○: Identifies that "Error handling for security failures" is delegated to Reliability, but security failures ARE security issues, creating a circular boundary. Suggests either (a) keeping security-specific error handling (e.g., "don't leak sensitive info in error messages") in Security scope, or (b) clarifying that only operational error handling (retry, fallback) goes to Reliability.
- △: Notices the delegation but doesn't identify the circularity problem, or notes it's confusing without suggesting a resolution.
- ×: Doesn't detect the circular reference issue.

**Bonus** (+0.5pt each):
- Suggests adding concrete examples of "what problems this perspective uniquely catches" to strengthen value proposition
- Notes that "Security best practices" (item 4) is too broad and should be narrowed to specific categories

**Penalty** (-0.5pt each):
- Criticizes scope items that are legitimate security concerns (e.g., claiming authentication is too broad)
- Suggests removing essential security items without proper justification

---

### T02: Overly Narrow Code Style Perspective (Easy)

**Max Possible**: 6 points (3 AKs × weight 1.0 × rating 2)

**AK-T02-01 (PB-04): Excessive Narrowness** [Weight: 1.0]
- ○: Identifies that the perspective is excessively narrow (only 3 scope items, all about whitespace/formatting). Notes that this creates a "trivial" perspective unlikely to catch meaningful architectural or design issues. Suggests either (a) expanding to "Code Formatting" (including bracket placement, import ordering), or (b) merging into a broader Code Quality perspective.
- △: Notes the perspective is narrow but doesn't assess whether this narrowness provides sufficient value or suggest how to address it.
- ×: Doesn't identify the excessive narrowness issue.

**AK-T02-02 (PB-05): Low Actionability - Automated Tool Domain** [Weight: 1.0]
- ○: Points out that all in-scope items (indentation, line length, trailing whitespace) are automatically handled by linters/formatters (e.g., ESLint, Prettier, Black). Questions the value of manual review for auto-fixable issues. Notes the contradiction that the penalty includes "auto-fixable issues" yet the entire scope consists of such issues.
- △: Mentions that these are linter-detectable but doesn't question the perspective's value given automation, or doesn't note the contradiction in the penalty guideline.
- ×: Doesn't identify the low actionability issue.

**AK-T02-03 (PB-06): Missing Critical Differentiation from Code Quality** [Weight: 1.0]
- ○: Identifies that the out-of-scope delegation to "Code Quality" is unclear. If this perspective only handles whitespace/formatting, what does "Code Quality" cover? Suggests clarifying the boundary by defining whether Code Quality includes all style issues (making this perspective redundant) or only semantic quality (naming, structure), in which case this perspective should be renamed "Formatting" not "Code Style."
- △: Notes the delegation to Code Quality but doesn't question the boundary clarity or redundancy issue.
- ×: Doesn't detect the unclear differentiation.

**Bonus** (+0.5pt each):
- Suggests concrete expansion options (e.g., adding bracket placement, import ordering)
- Questions whether a separate perspective is needed vs. relying on automated tooling

**Penalty** (-0.5pt each):
- Suggests removing essential formatting checks (e.g., claiming line length is irrelevant)
- Proposes merging without analyzing boundary clarity

---

### T03: Ambiguous Performance Perspective (Medium)

**Max Possible**: 8 points (4 AKs × weight 1.0 × rating 2)

**AK-T03-01 (PB-07): Overlapping Algorithmic Complexity with Code Quality** [Weight: 1.0]
- ○: Identifies that "Algorithmic complexity analysis" (item 4) overlaps with Code Quality or Maintainability perspectives. Notes that complexity can be viewed from multiple angles: runtime performance (O(n²) vs O(n log n)) vs. code maintainability (cognitive complexity). Suggests clarifying the boundary by limiting Performance scope to "runtime complexity impacting response time/throughput" and delegating cognitive complexity to Code Quality.
- △: Notes potential overlap with algorithmic complexity but doesn't specify which perspective or doesn't provide boundary clarification.
- ×: Doesn't detect the overlap.

**AK-T03-02 (PB-08): Ambiguous Caching Scope Boundary** [Weight: 1.0]
- ○: Points out that "Caching and data access patterns" (item 5) is ambiguous regarding boundary with Data Architecture. Where does "caching strategy" end and "data architecture" begin? For example, is Redis caching architecture a Performance issue or Data Architecture issue? Suggests clarifying with examples: "Performance covers cache hit/miss optimization and cache invalidation timing; Data Architecture covers cache technology selection and distributed cache topology."
- △: Notes the caching item but doesn't identify the boundary ambiguity with Data Architecture.
- ×: Doesn't detect the ambiguous boundary.

**AK-T03-03 (PB-09): Vague Penalty Criterion - "Measurable Impact"** [Weight: 1.0]
- ○: Identifies that the penalty "Performance concerns without measurable impact" is poorly defined. What constitutes "measurable impact"? Is a 10ms improvement measurable? 100ms? Suggests providing concrete thresholds (e.g., "improvements < 5% of total response time") or clarifying that the penalty applies to concerns that cannot be quantified at all (e.g., "might be slow" without profiling data).
- △: Notes the vague penalty but doesn't suggest how to make it concrete.
- ×: Doesn't question the penalty criterion.

**AK-T03-04 (PB-10): Database Schema Delegation Boundary Issue** [Weight: 1.0]
- ○: Identifies that "Database schema design" is delegated to Data Architecture, but many schema issues directly impact performance (e.g., missing indexes, denormalization for read performance, partitioning). Suggests clarifying that Performance can comment on "performance implications of schema decisions" while Data Architecture handles "schema structure and normalization."
- △: Notes the delegation but doesn't identify the potential overlap with performance-impacting schema decisions.
- ×: Doesn't detect the boundary issue.

**Bonus** (+0.5pt each):
- Suggests adding examples to distinguish performance-focused complexity from maintainability-focused complexity
- Proposes concrete thresholds for "measurable impact" in penalty guidelines
- Questions whether N+1 detection (bonus item) should be in-scope rather than bonus

**Penalty** (-0.5pt each):
- Suggests removing legitimate performance concerns (e.g., claiming caching is out of scope)
- Proposes boundaries that create gaps (e.g., no perspective covering cache invalidation)

---

### T04: Contradictory Reliability Perspective (Medium)

**Max Possible**: 8 points (4 AKs × weight 1.0 × rating 2)

**AK-T04-01 (PB-11): Contradictory Out-of-Scope - Security Error Responses** [Weight: 1.0]
- ○: Identifies the contradiction in delegating "Security-related error responses" to Security perspective. Error responses ARE part of error handling (in-scope item 1), and the security concern is specifically "don't leak sensitive info in errors." This creates circular dependency: Reliability owns error handling but must delegate security aspects to Security, which then needs to reference back to Reliability for error handling context. Suggests keeping "error response content" in Reliability scope and only delegating "authentication/authorization errors" to Security.
- △: Notes the delegation but doesn't identify the circular dependency or contradiction.
- ×: Doesn't detect the issue.

**AK-T04-02 (PB-12): Monitoring Scope Overlap with Operations** [Weight: 1.0]
- ○: Points out that "Monitoring and observability setup" (item 5) overlaps with the delegated "Logging infrastructure." Logging IS part of observability. Suggests clarifying the boundary: Reliability covers "what to monitor for reliability (error rates, latency, circuit breaker states)" while Operations covers "how to implement monitoring (infrastructure, tools, log aggregation)."
- △: Notes the monitoring item but doesn't identify the overlap with logging infrastructure.
- ×: Doesn't detect the overlap.

**AK-T04-03 (PB-13): Data Consistency Out of Place** [Weight: 1.0]
- ○: Questions whether "Data consistency in distributed systems" (item 4) belongs in Reliability perspective. Consistency is a fundamental distributed systems concern that could belong to Data Architecture or System Design perspectives. If the focus is "consistency during failures" (e.g., two-phase commit, sagas), it fits Reliability. If it's "consistency models (eventual, strong)" it belongs elsewhere. Suggests clarifying to "Consistency guarantees during error scenarios and retries."
- △: Notes the data consistency item but doesn't question its fit or suggest clarification.
- ×: Doesn't detect the potential scope misalignment.

**AK-T04-04 (PB-14): Penalty Assumes Knowledge Not in Scope** [Weight: 1.0]
- ○: Identifies that the penalty "Suggesting retry logic without considering idempotency" assumes the reviewer knows about idempotency, but idempotency is not mentioned in the in-scope items. Suggests adding "Idempotency considerations for retry safety" to the scope or removing this penalty criterion.
- △: Notes the penalty but doesn't identify the gap between penalty assumption and scope.
- ×: Doesn't question the penalty criterion.

**Bonus** (+0.5pt each):
- Suggests concrete examples to clarify "consistency during failures" vs. "consistency models"
- Proposes boundary definition that distinguishes "what to monitor" (Reliability) from "how to monitor" (Operations)
- Questions whether bonus items (silent failures, timeouts) should be promoted to in-scope given their importance

**Penalty** (-0.5pt each):
- Suggests removing legitimate reliability concerns (e.g., claiming monitoring is out of scope)
- Proposes boundaries that create coverage gaps for critical reliability aspects

---

### T05: Incomplete Cross-Reference Perspective (Medium)

**Max Possible**: 6 points (3 AKs × weight 1.0 × rating 2)

**AK-T05-01 (PB-15): Unverified Cross-Reference - Testing Perspective** [Weight: 1.0]
- ○: Identifies that "Test coverage" is delegated to Testing perspective, but the question is: does Testing perspective actually exist and does it cover test coverage? Without verifying the cross-reference, this creates a potential gap. Suggests adding a note "(if Testing perspective exists)" or verifying that the delegated item is actually covered by the referenced perspective.
- △: Notes the delegation but doesn't question whether the Testing perspective exists or covers this item.
- ×: Doesn't detect the unverified cross-reference issue.

**AK-T05-02 (PB-16): Boundary Ambiguity with Design Patterns and Performance** [Weight: 1.0]
- ○: Points out that "Design pattern appropriateness" (item 4) can overlap with Performance perspective. For example, is Singleton pattern a maintainability concern (global state makes testing hard) or a performance concern (lazy initialization, memory usage)? Suggests clarifying that Maintainability evaluates patterns from "testability, modularity, and change impact" perspective while Performance evaluates "runtime efficiency."
- △: Notes the design patterns item but doesn't identify potential overlap with Performance.
- ×: Doesn't detect the boundary ambiguity.

**AK-T05-03 (PB-17): Circular Dependency Bonus Should Be In-Scope** [Weight: 1.0]
- ○: Questions why "Identification of circular dependencies" is a bonus rather than in-scope. Circular dependencies are a core maintainability issue directly related to "Dependency management and coupling" (item 2). Suggests promoting it to in-scope or explaining why it's considered above-and-beyond.
- △: Notes the bonus item but doesn't question why it's not in-scope given its relevance to item 2.
- ×: Doesn't detect the misalignment.

**Bonus** (+0.5pt each):
- Suggests verifying all cross-references to ensure delegated items are actually covered
- Proposes examples to clarify "maintainability lens" vs. "performance lens" for design patterns
- Questions whether "God classes" (bonus) should also be in-scope given its relation to modularity (item 1)

**Penalty** (-0.5pt each):
- Suggests removing legitimate maintainability concerns (e.g., claiming dependency management is too broad)
- Proposes boundaries that create gaps in coverage

---

### T06: Well-Defined Consistency Perspective (Hard)

**Max Possible**: 8 points (4 AKs × weight 1.0 × rating 2)

**AK-T06-01 (PB-18): Subtle Overlap - Naming Consistency vs Code Style** [Weight: 1.0]
- ○: Identifies that "Naming consistency" (item 1) has a subtle boundary with Code Style perspective. The example given (user_service vs UserService) could be interpreted as a style issue (snake_case vs PascalCase) OR a consistency issue (using different conventions in different modules). Suggests clarifying that Consistency focuses on "cross-module/cross-file naming alignment" while Code Style focuses on "within-file formatting rules." However, also notes that if Code Style is only about whitespace (per the out-of-scope), this boundary is already clear.
- △: Notes the naming consistency item but doesn't examine the subtle boundary or provide clarification.
- ×: Doesn't detect the potential overlap.

**AK-T06-02 (PB-19): Value Proposition Strength - Concrete Examples** [Weight: 1.0]
- ○: Affirms that the value proposition is strong because the purpose statement includes concrete impact ("create confusion or maintenance burden") and each scope item has specific examples. Notes that without this perspective, issues like "User.id type mismatch between DB and API" (item 3) or "inconsistent error codes" (item 5) would likely be missed. These are actionable, fixable issues with clear benefit.
- △: Acknowledges good examples but doesn't analyze what problems would be missed or assess actionability.
- ×: Doesn't evaluate the value proposition strength.

**AK-T06-03 (PB-20): Penalty Edge Case - "Documented Rationale"** [Weight: 1.0]
- ○: Questions the penalty "Flagging intentional inconsistencies with documented rationale." This assumes the reviewer has access to and reads all rationale documentation. What if the rationale is in a different document or only in code comments? Suggests clarifying that the penalty applies when "rationale is present in the reviewed material" or adjusting to "Flagging inconsistencies without first checking for documented rationale."
- △: Notes the penalty but doesn't identify the assumption or edge case.
- ×: Doesn't question the penalty criterion.

**AK-T06-04 (PB-21): Architectural Pattern Consistency - Scope Boundary** [Weight: 1.0]
- ○: Notes that "Architectural pattern consistency" (item 2) could overlap with a System Architecture or Design Patterns perspective if such perspectives exist. The example (mixing REST and GraphQL) is an architectural decision. Suggests that Consistency should focus on "inconsistent application of chosen patterns" (e.g., REST endpoints with inconsistent URL structures) while System Architecture handles "architectural style selection and justification."
- △: Notes the architectural patterns item but doesn't question potential overlap or propose boundary clarification.
- ×: Doesn't detect the potential scope boundary issue.

**Bonus** (+0.5pt each):
- Praises the inclusion of concrete examples in each scope item as a model for other perspectives
- Suggests adding cross-reference verification (e.g., "if System Architecture perspective exists")
- Notes that timezone handling (bonus item) might be important enough to promote to in-scope

**Penalty** (-0.5pt each):
- Suggests removing legitimate consistency concerns (e.g., claiming naming consistency is trivial)
- Proposes boundaries that would create gaps in consistency coverage

---

### T07: Non-Actionable Best Practices Perspective (Hard)

**Max Possible**: 8 points (4 AKs × weight 1.0 × rating 2)

**AK-T07-01 (PB-22): Non-Actionable Output Pattern - "Should Follow"** [Weight: 1.0]
- ○: Identifies that the scope consists entirely of abstract principles (SOLID, DRY, least privilege, separation of concerns) without concrete detection criteria. This creates a high risk of non-actionable outputs like "This class violates Single Responsibility Principle. Consider refactoring." without specifying what responsibilities to separate or how. Suggests adding concrete detection patterns for each principle (e.g., "SRP violation: class has >3 public methods with unrelated purposes" or "DRY violation: identical code blocks >5 lines in ≥2 locations").
- △: Notes the abstract nature of the scope but doesn't identify the actionability risk or suggest concrete criteria.
- ×: Doesn't detect the non-actionable output pattern risk.

**AK-T07-02 (PB-23): Massive Overlap with Multiple Perspectives** [Weight: 1.0]
- ○: Points out that this perspective overlaps with nearly every other perspective: SOLID (Maintainability), Design patterns (Maintainability, Performance, Reliability), DRY (Code Quality, Maintainability), Least privilege (Security), Separation of concerns (Maintainability). Questions whether this is a meta-perspective that duplicates others. Suggests either (a) retiring this perspective and distributing items to specific perspectives, or (b) redefining as "Cross-cutting Principles Compliance" with explicit coordination with other perspectives.
- △: Notes some overlaps but doesn't identify the systemic duplication across multiple perspectives or question the perspective's existence.
- ×: Doesn't detect the massive overlap issue.

**AK-T07-03 (PB-24): Bonus/Penalty Contradict Each Other** [Weight: 1.0]
- ○: Identifies contradiction between bonus "Detection of premature abstraction" and penalty "Over-applying patterns where simple solutions suffice." Both address the same issue (over-engineering) from different angles. This creates confusion: is detecting premature abstraction a bonus-worthy achievement or a basic expectation? Suggests consolidating to one entry (either bonus OR penalty) or clarifying that bonus applies to subtle cases while penalty applies to flagrant over-engineering.
- △: Notes similarity between the items but doesn't identify the contradiction or confusion.
- ×: Doesn't detect the bonus/penalty contradiction.

**AK-T07-04 (PB-25): Recursive Bonus - "Missing SOLID Principles"** [Weight: 1.0]
- ○: Questions the bonus "Identification of missing SOLID principles." SOLID principles are already in-scope (item 1), so detecting missing SOLID adherence should be the baseline expectation, not a bonus. Suggests either (a) removing this bonus, or (b) clarifying that bonus applies to "detecting violation of SOLID principles not commonly checked" (e.g., Dependency Inversion Principle, which is often overlooked).
- △: Notes the bonus but doesn't identify that it duplicates the in-scope item.
- ×: Doesn't detect the recursive bonus issue.

**Bonus** (+0.5pt each):
- Suggests concrete metrics for each principle (e.g., "DRY: code duplication >5 lines in ≥2 files")
- Proposes retiring this perspective and distributing items to domain-specific perspectives
- Questions whether "best practices" is too vague to be a standalone perspective

**Penalty** (-0.5pt each):
- Suggests that abstract principles are sufficient without concrete criteria
- Defends the massive overlap as "important enough to repeat"

---

### T08: Boundary Case - Infrastructure Cost Perspective (Hard)

**Max Possible**: 6 points (3 AKs × weight 1.0 × rating 2)

**AK-T08-01 (PB-26): Scope Boundary - Performance Overlap Complex** [Weight: 1.0]
- ○: Identifies that the boundary between Cost and Performance perspectives is complex and potentially problematic. "Resource rightsizing" (item 1) and "cost-effective architecture patterns" (item 3) inherently involve performance tradeoffs (e.g., smaller VM = lower cost but potentially worse performance). The delegation "Performance implications of cost optimization → Performance" creates circular dependency: Cost perspective identifies rightsizing opportunity, but must delegate performance impact analysis to Performance, which then needs to evaluate cost implications. Suggests clarifying that Cost perspective can mention "performance tradeoffs" but Performance perspective owns the detailed analysis, OR defining joint responsibility for cost-performance tradeoff decisions.
- △: Notes the delegation to Performance but doesn't identify the circular dependency or complexity of the boundary.
- ×: Doesn't detect the scope boundary issue.

**AK-T08-02 (PB-27): Domain-Specific Perspective - Limited Applicability** [Weight: 1.0]
- ○: Questions whether this perspective has broad enough applicability. Infrastructure cost is only relevant for cloud/infrastructure design reviews, not for application code reviews, API design, or many other review types. Notes that 80%+ of scope items are cloud-specific (VMs, serverless, reserved capacity, cross-region transfer). Suggests either (a) renaming to "Cloud Infrastructure Cost" to clarify limited scope, or (b) acknowledging this is a specialized perspective only activated for infrastructure reviews.
- △: Notes the cloud focus but doesn't question overall applicability or suggest clarification.
- ×: Doesn't detect the limited applicability issue.

**AK-T08-03 (PB-28): Penalty Assumes Business Context** [Weight: 1.0]
- ○: Points out that the penalty "Recommending changes without ROI analysis" assumes the reviewer has access to business context (current costs, usage patterns, change implementation costs). In many review scenarios, this data is not available in the design document. Suggests either (a) clarifying that this penalty applies "when cost data is provided in the reviewed material," or (b) adjusting to "Recommending changes without considering ROI factors" (qualitative vs. quantitative).
- △: Notes the penalty but doesn't identify the data availability assumption.
- ×: Doesn't question the penalty criterion.

**Bonus** (+0.5pt each):
- Suggests adding scope clarification about when this perspective is applicable (infrastructure reviews only)
- Proposes concrete examples of "cost-performance tradeoff analysis" to clarify the boundary
- Questions whether cost monitoring (bonus item) should be in-scope given its importance

**Penalty** (-0.5pt each):
- Suggests that domain-specific perspectives are inherently problematic (they're not, if well-scoped)
- Proposes removing the performance delegation without addressing the circular dependency

---

## Problem Bank Summary

**Total Problems**: 28 (unique: 28, due to cross-category problems counted once)

**By Category**:
- Value Recognition: 9 problems
- Boundary Clarity: 12 problems
- Scope Assessment: 6 problems
- Evidence Analysis: 10 problems

**By Importance**:
- High: 8 problems (29%)
- Medium: 18 problems (64%)
- Low: 2 problems (7%)

**Distribution Across Scenarios**:
- Easy (T01-T02): 6 problems (3 per scenario)
- Medium (T03-T05): 11 problems (3-4 per scenario)
- Hard (T06-T08): 11 problems (3-4 per scenario)

**Cross-Category Problems** (testing multiple capabilities):
- PB-02: Value Recognition + Boundary Clarity
- PB-06: Value Recognition + Boundary Clarity
- PB-10: Boundary Clarity + Evidence Analysis
- PB-12: Boundary Clarity + Evidence Analysis
- PB-14: Scope Assessment + Evidence Analysis
- PB-16: Boundary Clarity + Evidence Analysis
- PB-19: Value Recognition + Evidence Analysis
- PB-22: Value Recognition + Evidence Analysis
