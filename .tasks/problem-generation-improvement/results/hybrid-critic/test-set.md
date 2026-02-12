# Test Scenario Set: critic-effectiveness

**Agent**: critic-effectiveness
**Type**: Type-C (Meta-evaluation Agent)
**Input Type**: Perspective definition files
**Generated**: 2026-02-12

---

## Test Scenarios

### T01: Generic Security Perspective

**Difficulty**: Easy
**Category**: Value Recognition, Boundary Clarity
**Embedded Problems**: PB-01, PB-02, PB-03

#### Input

```markdown
# Security Perspective

## Purpose
Evaluate security aspects of the system.

## Scope (In-Scope)
1. Authentication and authorization mechanisms
2. Data protection and encryption
3. Input validation and sanitization
4. Security best practices
5. Vulnerability detection

## Scope (Out-of-Scope)
- Performance implications of security measures → refer to Performance perspective
- Error handling for security failures → refer to Reliability perspective

## Bonus (+0.5pt each)
- Detection of security misconfigurations
- Identification of outdated security libraries

## Penalty (-0.5pt each)
- False positives on security issues
```

#### Answer Key

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

#### Expected Key Behaviors
- Identifies vague purpose statements and suggests concrete problem examples
- Detects scope overlaps and proposes clear boundary definitions
- Recognizes circular or contradictory cross-references
- Distinguishes between "broad but valid" scope vs. "vague and actionable" scope

#### Anti-patterns
- Accepting generic purpose statements without questioning value contribution
- Missing obvious scope overlaps with common perspectives
- Not questioning the logic of cross-references

---

### T02: Overly Narrow Code Style Perspective

**Difficulty**: Easy
**Category**: Scope Assessment, Value Recognition
**Embedded Problems**: PB-04, PB-05, PB-06

#### Input

```markdown
# Code Style Perspective

## Purpose
Ensure consistent indentation and line length in source code.

## Scope (In-Scope)
1. Indentation (spaces vs. tabs, indent size)
2. Line length limits (80 or 120 characters)
3. Trailing whitespace detection

## Scope (Out-of-Scope)
- Naming conventions → refer to Code Quality perspective
- Comment quality → refer to Documentation perspective
- Function complexity → refer to Maintainability perspective

## Bonus (+0.5pt each)
- Detection of mixed indentation styles
- Identification of excessively long lines

## Penalty (-0.5pt each)
- Suggestions for auto-fixable issues that linters handle
```

#### Answer Key

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

#### Expected Key Behaviors
- Recognizes when scope is too narrow to provide meaningful value
- Identifies contradictions between scope and penalty guidelines
- Questions the need for manual review when automation is available
- Proposes concrete expansion or consolidation options

#### Anti-patterns
- Accepting narrow scope without assessing value contribution
- Missing the automation vs. manual review tension
- Not questioning unclear boundaries with related perspectives

---

### T03: Ambiguous Performance Perspective

**Difficulty**: Medium
**Category**: Boundary Clarity, Evidence Analysis
**Embedded Problems**: PB-07, PB-08, PB-09, PB-10

#### Input

```markdown
# Performance Perspective

## Purpose
Identify performance issues and optimization opportunities in system design.

## Scope (In-Scope)
1. Response time and latency optimization
2. Throughput and scalability considerations
3. Resource utilization efficiency
4. Algorithmic complexity analysis
5. Caching and data access patterns

## Scope (Out-of-Scope)
- Infrastructure cost optimization → refer to Cost Management perspective
- Database schema design → refer to Data Architecture perspective

## Bonus (+0.5pt each)
- Detection of N+1 query problems
- Identification of unnecessary data processing
- Recognition of missing performance metrics

## Penalty (-0.5pt each)
- Premature optimization suggestions
- Performance concerns without measurable impact
```

#### Answer Key

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

#### Expected Key Behaviors
- Detects overlaps with multiple related perspectives (Code Quality, Data Architecture)
- Identifies vague boundary definitions and suggests concrete clarifications
- Questions penalty criteria that lack concrete thresholds
- Proposes boundary definitions that avoid gaps and overlaps

#### Anti-patterns
- Missing overlaps when scope items naturally belong to multiple perspectives
- Accepting vague delegation statements without questioning boundary cases
- Not recognizing when penalty criteria are subjective or unenforceable

---

### T04: Contradictory Reliability Perspective

**Difficulty**: Medium
**Category**: Scope Assessment, Evidence Analysis
**Embedded Problems**: PB-11, PB-12, PB-13, PB-14

#### Input

```markdown
# Reliability Perspective

## Purpose
Ensure system reliability through proper error handling and fault tolerance.

## Scope (In-Scope)
1. Error handling and exception management
2. Retry logic and circuit breaker patterns
3. Fallback mechanisms and graceful degradation
4. Data consistency in distributed systems
5. Monitoring and observability setup

## Scope (Out-of-Scope)
- Logging infrastructure → refer to Operations perspective
- Security-related error responses → refer to Security perspective
- Performance impact of retry mechanisms → refer to Performance perspective

## Bonus (+0.5pt each)
- Detection of silent failures
- Identification of missing timeout configurations
- Recognition of improper error propagation

## Penalty (-0.5pt each)
- Over-engineering fault tolerance for low-risk scenarios
- Suggesting retry logic without considering idempotency
```

#### Answer Key

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

#### Expected Key Behaviors
- Detects contradictions between in-scope and out-of-scope items
- Identifies overlaps when delegated items are closely related to in-scope items
- Questions whether scope items belong in this perspective vs. others
- Verifies that penalty criteria align with in-scope capabilities

#### Anti-patterns
- Accepting contradictory scope definitions without question
- Missing overlaps between in-scope items and delegated infrastructure
- Not questioning whether specific items belong in this perspective
- Failing to verify that penalties align with scope

---

### T05: Incomplete Cross-Reference Perspective

**Difficulty**: Medium
**Category**: Boundary Clarity, Evidence Analysis
**Embedded Problems**: PB-15, PB-16, PB-17

#### Input

```markdown
# Maintainability Perspective

## Purpose
Evaluate code and design for long-term maintainability and extensibility.

## Scope (In-Scope)
1. Code modularity and separation of concerns
2. Dependency management and coupling
3. Code duplication and reusability
4. Design pattern appropriateness
5. Technical debt identification

## Scope (Out-of-Scope)
- Test coverage → refer to Testing perspective
- Documentation quality → refer to Documentation perspective
- Performance optimization → refer to Performance perspective
- Security vulnerabilities → refer to Security perspective

## Bonus (+0.5pt each)
- Detection of God classes or objects
- Identification of circular dependencies
- Recognition of unnecessary abstractions

## Penalty (-0.5pt each):
- Nitpicking on minor style issues
- Suggesting refactoring without clear benefit
```

#### Answer Key

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

#### Expected Key Behaviors
- Verifies that cross-references point to items actually covered by referenced perspectives
- Identifies boundary ambiguities when items can be viewed from multiple perspectives
- Questions bonus/penalty categorization when items seem core to the scope
- Proposes boundary clarifications based on "lens" or "angle of analysis"

#### Anti-patterns
- Accepting cross-references without verifying the referenced perspective exists/covers the item
- Missing overlaps when items have multi-dimensional concerns
- Not questioning why core issues are categorized as bonus

---

### T06: Well-Defined Consistency Perspective

**Difficulty**: Hard
**Category**: Value Recognition, Boundary Clarity, Evidence Analysis
**Embedded Problems**: PB-18, PB-19, PB-20, PB-21

#### Input

```markdown
# Consistency Perspective

## Purpose
Ensure consistency across system design, implementation, and documentation. Detect contradictions, naming inconsistencies, and architectural misalignments that create confusion or maintenance burden.

## Scope (In-Scope)
1. Naming consistency across components (e.g., "user_service" vs "UserService" in different modules)
2. Architectural pattern consistency (e.g., mixing REST and GraphQL without justification)
3. Data model consistency (e.g., User.id as integer in DB but string in API)
4. Documentation-to-implementation consistency (e.g., outdated API docs)
5. Error handling pattern consistency (e.g., some endpoints return 400, others 422 for validation)

## Scope (Out-of-Scope)
- Code style formatting (indentation, line breaks) → refer to Code Style perspective
- Business logic correctness → refer to Functional Correctness perspective
- Performance implications of consistency choices → refer to Performance perspective

## Bonus (+0.5pt each)
- Detection of inconsistent abbreviation usage (e.g., "msg" vs "message")
- Identification of mixed paradigms (e.g., OOP and functional patterns without clear separation)
- Recognition of timezone handling inconsistencies

## Penalty (-0.5pt each)
- Flagging intentional inconsistencies with documented rationale
- Suggesting consistency changes that break backward compatibility
```

#### Answer Key

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

#### Expected Key Behaviors
- Examines subtle boundaries even when scope seems clear
- Evaluates value proposition based on concrete problem examples
- Questions penalty assumptions about reviewer access to information
- Verifies whether specialized items overlap with potential domain-specific perspectives
- Recognizes well-defined perspectives while still identifying edge cases

#### Anti-patterns
- Assuming no issues exist when scope has good examples
- Not questioning penalty criteria that assume reviewer omniscience
- Missing subtle overlaps between cross-cutting concerns

---

### T07: Non-Actionable Best Practices Perspective

**Difficulty**: Hard
**Category**: Evidence Analysis, Value Recognition
**Embedded Problems**: PB-22, PB-23, PB-24, PB-25

#### Input

```markdown
# Best Practices Perspective

## Purpose
Ensure adherence to industry best practices and standards.

## Scope (In-Scope)
1. Adherence to SOLID principles
2. Proper use of design patterns
3. Following the DRY principle (Don't Repeat Yourself)
4. Applying the principle of least privilege
5. Ensuring appropriate separation of concerns

## Scope (Out-of-Scope)
- Language-specific idioms → refer to Language Expertise perspective
- Performance optimization → refer to Performance perspective

## Bonus (+0.5pt each)
- Recognition of YAGNI violations (You Aren't Gonna Need It)
- Detection of premature abstraction
- Identification of missing SOLID principles

## Penalty (-0.5pt each):
- Suggesting best practices that contradict project requirements
- Over-applying patterns where simple solutions suffice
```

#### Answer Key

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

#### Expected Key Behaviors
- Recognizes when scope items lead to "awareness-only" outputs rather than actionable fixes
- Identifies systemic overlap across multiple perspectives
- Detects contradictions between bonus and penalty guidelines
- Questions whether bonus items duplicate in-scope expectations
- Evaluates whether a perspective provides unique value vs. duplicating others

#### Anti-patterns
- Accepting abstract principles as scope without questioning actionability
- Missing systemic overlaps when perspective duplicates many others
- Not detecting logical contradictions between bonus/penalty items
- Failing to question whether a perspective should exist vs. being distributed

---

### T08: Boundary Case - Infrastructure Cost Perspective

**Difficulty**: Hard
**Category**: Boundary Clarity, Scope Assessment, Value Recognition
**Embedded Problems**: PB-26, PB-27, PB-28

#### Input

```markdown
# Infrastructure Cost Perspective

## Purpose
Optimize infrastructure costs and resource allocation efficiency.

## Scope (In-Scope)
1. Cloud resource rightsizing (e.g., over-provisioned VMs)
2. Unused or underutilized resources
3. Cost-effective architecture patterns (e.g., serverless vs. containers)
4. Data transfer and storage cost optimization
5. Reserved capacity vs. on-demand pricing strategies

## Scope (Out-of-Scope)
- Performance implications of cost optimization → refer to Performance perspective
- Application-level efficiency → refer to Performance perspective
- Security implications of shared resources → refer to Security perspective

## Bonus (+0.5pt each)
- Detection of orphaned resources (e.g., unattached EBS volumes)
- Identification of cross-region data transfer costs
- Recognition of missing cost monitoring/alerting

## Penalty (-0.5pt each):
- Suggesting cost cuts that compromise reliability
- Recommending changes without ROI analysis
```

#### Answer Key

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

#### Expected Key Behaviors
- Identifies complex circular dependencies in scope delegation
- Questions applicability when perspective is domain-specific
- Examines penalty criteria for data availability assumptions
- Distinguishes between "limited but well-defined scope" vs. "problematically narrow scope"

#### Anti-patterns
- Missing circular dependencies in multi-perspective tradeoff scenarios
- Not questioning whether specialized perspectives need applicability constraints
- Accepting penalty criteria that assume information not typically available

---

## Summary

| ID | Title | Difficulty | Embedded Problems | Category | AK Count |
|----|-------|-----------|------------------|----------|----------|
| T01 | Generic Security Perspective | Easy | PB-01, PB-02, PB-03 | Value Recognition, Boundary Clarity | 3 |
| T02 | Overly Narrow Code Style Perspective | Easy | PB-04, PB-05, PB-06 | Scope Assessment, Value Recognition | 3 |
| T03 | Ambiguous Performance Perspective | Medium | PB-07, PB-08, PB-09, PB-10 | Boundary Clarity, Evidence Analysis | 4 |
| T04 | Contradictory Reliability Perspective | Medium | PB-11, PB-12, PB-13, PB-14 | Scope Assessment, Evidence Analysis | 4 |
| T05 | Incomplete Cross-Reference Perspective | Medium | PB-15, PB-16, PB-17 | Boundary Clarity, Evidence Analysis | 3 |
| T06 | Well-Defined Consistency Perspective | Hard | PB-18, PB-19, PB-20, PB-21 | Value Recognition, Boundary Clarity, Evidence Analysis | 4 |
| T07 | Non-Actionable Best Practices Perspective | Hard | PB-22, PB-23, PB-24, PB-25 | Evidence Analysis, Value Recognition | 4 |
| T08 | Boundary Case - Infrastructure Cost Perspective | Hard | PB-26, PB-27, PB-28 | Boundary Clarity, Scope Assessment, Value Recognition | 3 |

**Total**: 8 scenarios, 28 embedded problems, 28 answer keys
