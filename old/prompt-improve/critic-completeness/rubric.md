# Evaluation Rubric: critic-completeness

Agent: critic-completeness
Version: v001-baseline
Generated: 2026-02-11

This rubric consolidates all scoring criteria from the test scenarios.

---

## Scoring Criteria by Scenario

### T01: Well-Structured Security Perspective with Minor Gaps

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T01-C1 | Scope Coverage Completeness | Identifies that scope adequately covers security domain with only minor gaps (e.g., session management, rate limiting) | Mentions scope is generally adequate but misses specific gap analysis | Does not evaluate scope coverage systematically | 1.0 |
| T01-C2 | Missing Element Detection Analysis | Provides 5+ essential security design elements and evaluates detectability for each | Lists 3-4 elements OR evaluates detectability superficially | Lists fewer than 3 elements or no detectability analysis | 1.0 |
| T01-C3 | Problem Bank Severity Distribution | Notes that severity distribution is appropriate (3 critical, 3 moderate, 2 minor) | Mentions severity distribution without quantitative analysis | Does not evaluate severity distribution | 0.5 |
| T01-C4 | Actionable Improvement Proposals | Proposes 2-3 specific additions (e.g., "add session management to scope", "add rate limiting issue to problem bank") | Proposes 1 improvement OR proposals are vague | No concrete proposals | 1.0 |

**Expected Key Behaviors:**
- Recognize that the perspective is well-structured with adequate coverage
- Identify minor gaps (e.g., session management, rate limiting, CSRF protection)
- Confirm that problem bank includes "missing element" type issues (SEC-001, SEC-002, SEC-003)
- Provide specific, actionable recommendations for minor improvements

**Anti-patterns:**
- Overly critical evaluation of a fundamentally sound perspective
- Vague feedback like "add more security concerns" without specifics
- Missing the distinction between critical/moderate/minor severity
- Failing to acknowledge well-designed elements

---

### T02: Performance Perspective Missing Critical Detection Capability

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T02-C1 | Detection of Missing Caching Strategy | Identifies that "caching" is completely absent from evaluation scope and problem bank, with specific proposal to add it | Mentions caching briefly but without specific addition proposal | Does not identify caching as missing critical element | 1.0 |
| T02-C2 | Missing Element Detection Table | Provides table with 5+ essential performance elements (e.g., caching, rate limiting, lazy loading, data pagination) and detectability analysis for each | Provides 3-4 elements OR incomplete detectability analysis | Fewer than 3 elements or no structured analysis | 1.0 |
| T02-C3 | Problem Bank Gap Identification | Identifies that problem bank lacks "missing cache" or "no pagination" type issues, proposes specific additions | Mentions problem bank gaps generally without specific proposals | Does not evaluate problem bank coverage | 1.0 |
| T02-C4 | Severity Distribution Assessment | Notes insufficient critical issues (only 2) and proposes elevation or addition | Mentions severity imbalance without specific action | Does not evaluate severity distribution | 0.5 |

**Expected Key Behaviors:**
- Detect that caching is a critical performance element completely absent from scope and problem bank
- Identify other missing critical elements (e.g., pagination for large datasets, rate limiting, lazy evaluation)
- Propose specific additions: "Add 'Caching Strategy' as scope item 6" and "Add PERF-007 (Critical): No caching mechanism for frequently accessed data"
- Evaluate whether AI reviewer following this perspective could detect "design with no caching" (answer: NO)

**Anti-patterns:**
- Focusing only on present elements without detecting absent critical elements
- Vague statements like "could add more performance concerns"
- Failing to distinguish between "nice to have" and "critical missing element"
- Not using the missing element detection framework

---

### T03: Consistency Perspective with Ambiguous Scope Items

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T03-C1 | Overlap with Other Perspectives | Identifies that "Code Organization" and "Design Patterns" overlap significantly with maintainability/architecture perspectives, proposes narrowing scope | Mentions overlap but without specific action | Does not identify scope overlap issue | 1.0 |
| T03-C2 | Ambiguity in Scope Items | Points out that "Naming Conventions" is too broad (spans variables, functions, classes, constants, files, etc.) and proposes more focused definition | Mentions breadth but without actionable proposal | Does not identify ambiguity | 1.0 |
| T03-C3 | Missing Element Detection for Consistency | Identifies missing consistency areas (e.g., API versioning consistency, database schema naming, configuration format consistency) | Lists 1-2 missing areas without detectability analysis | Does not identify missing consistency elements | 1.0 |
| T03-C4 | Problem Bank Improvement | Notes insufficient critical issues (only 1) and proposes specific additions like "No consistent API contract format" or "Mixed configuration formats" | General comment about problem bank without specific proposals | Does not evaluate problem bank | 0.5 |
| T03-C5 | Actionable Scope Refinement | Proposes specific rewording: e.g., "Naming Conventions → Identifier Naming Consistency (variables, functions, classes)" | Suggests refinement without concrete examples | No scope refinement proposal | 1.0 |

**Expected Key Behaviors:**
- Identify that "Code Organization" and "Design Patterns" are too broad and overlap with other perspectives
- Propose narrowing scope to consistency-specific aspects (e.g., "consistent application of chosen pattern" rather than "pattern selection")
- Detect missing consistency areas: API contract consistency, schema naming, configuration format
- Provide specific scope item rewording suggestions

**Anti-patterns:**
- Accepting overly broad scope items without questioning
- Missing overlap analysis with other perspectives (maintainability, architecture)
- Vague feedback like "clarify scope items"
- Not proposing concrete rewording

---

### T04: Minimal Maintainability Perspective Lacking Examples

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T04-C1 | Problem Bank Insufficiency | Identifies that only 3 problems exist (guideline: 8-12), with severe gaps in coverage of scope items 2, 4, 5 | Notes problem bank is sparse but without quantitative analysis | Does not evaluate problem bank size/coverage | 1.0 |
| T04-C2 | Missing "Should Exist" Type Issues | Identifies that problem bank lacks "missing element" issues (e.g., "No modular architecture", "No extension points defined", "No deprecation policy") and proposes 3+ specific additions | Mentions need for omission-type issues but proposes fewer than 3 | Does not identify this gap | 1.0 |
| T04-C3 | Severity Distribution Problem | Notes that there are insufficient critical (only 1) and moderate (only 1) issues, proposes specific additions or severity adjustments | General comment about severity without specific action | Does not evaluate severity distribution | 0.5 |
| T04-C4 | Missing Element Detection Capability | Evaluates whether AI reviewer could detect "design with no testing strategy" (scope item 4) and concludes NO due to problem bank gap, proposes specific problem addition | Partial analysis without actionable proposal | No missing element detection evaluation | 1.0 |
| T04-C5 | Scope vs Problem Bank Alignment | Identifies that scope items "Extensibility" and "Technical Debt Management" have zero problem bank examples, proposes at least 1 problem per scope item | Notes misalignment but without specific additions | Does not evaluate scope-problem alignment | 1.0 |
| T04-C6 | Evidence Keyword Quality | Points out that evidence keywords are too generic ("complex logic", "unclear naming") and proposes more specific keywords | Mentions keyword quality without proposals | Does not evaluate evidence keywords | 0.5 |

**Expected Key Behaviors:**
- Recognize severe problem bank insufficiency (only 3 problems vs. guideline 8-12)
- Identify complete absence of problems for scope items 2 (Extensibility), 5 (Technical Debt Management)
- Propose specific "missing element" type problems: e.g., "MAINT-004 (Critical): No defined extension points or plugin architecture", "MAINT-005 (Moderate): No deprecation policy for legacy code"
- Evaluate missing element detectability and conclude current definition is insufficient
- Provide 5+ specific problem additions with severity, description, and evidence keywords

**Anti-patterns:**
- Superficial problem bank evaluation without quantitative analysis
- Missing the critical link between scope items and problem bank coverage
- Proposing generic additions like "add more problems"
- Failing to identify the "missing element detection" gap despite it being the agent's primary responsibility

---

### T05: Architecture Perspective with Conflicting Priorities

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T05-C1 | Technology Stack Scope Concern | Identifies that "Technology Stack Selection" is overly broad and overlaps with security, performance, and maintainability perspectives (e.g., framework performance, security vulnerabilities in libraries) | Mentions overlap without specific analysis | Does not identify scope issue | 1.0 |
| T05-C2 | Missing Element Detection | Provides 5+ essential architecture elements (e.g., API gateway, service mesh, caching layer, authentication service) and evaluates detectability | Lists 3-4 elements OR incomplete detectability analysis | Fewer than 3 elements or no analysis | 1.0 |
| T05-C3 | Scope Refinement Proposal | Proposes narrowing "Technology Stack Selection" to architecture-specific aspects (e.g., "Architectural Pattern Implementation - Framework support for chosen patterns, technology alignment with architectural style") | Suggests refinement without concrete rewording | No refinement proposal | 1.0 |
| T05-C4 | Problem Bank Coverage | Notes that "System Decomposition" (scope item 1) lacks "missing element" type problems (e.g., "No defined service boundaries", "Monolith without clear module separation") and proposes additions | General comment without specific additions | Does not evaluate problem bank coverage | 1.0 |

**Expected Key Behaviors:**
- Identify that "Technology Stack Selection" is too broad and infringes on other perspectives' domains
- Propose scope refinement to focus on architecture-specific technology concerns
- Detect missing architecture elements: API gateway, service mesh, caching architecture, authentication/authorization infrastructure
- Recognize good severity distribution and problem bank diversity
- Balance critical feedback with acknowledgment of well-structured elements

**Anti-patterns:**
- Accepting broad scope items that overlap with other perspectives
- Missing the distinction between "technology choice" (broad) and "technology alignment with architecture" (focused)
- Failing to propose concrete scope rewording
- Only providing negative feedback without acknowledging strong aspects

---

### T06: Reliability Perspective with Strong Detection Capability

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T06-C1 | Recognition of Strong Design | Explicitly acknowledges that the perspective is well-designed with good scope coverage, appropriate severity distribution (3 critical, 4 moderate, 2 minor), and strong missing element detection capability | Acknowledges some strengths without comprehensive evaluation | Does not acknowledge strengths | 1.0 |
| T06-C2 | Missing Element Detection Validation | Provides 5+ essential reliability elements and confirms detectability for each, concluding that the perspective enables effective omission detection | Lists 3-4 elements OR incomplete confirmation of detectability | Fewer than 3 elements or no detectability validation | 1.0 |
| T06-C3 | Minor Improvement Identification | Identifies 1-2 minor enhancements despite overall strong design (e.g., "Add disaster recovery to scope", "Add chaos engineering testing to problem bank") | Vague suggestions without specifics | States "no improvements needed" without thorough analysis | 0.5 |
| T06-C4 | Balanced Evaluation | Provides balanced report emphasizing positive aspects while including constructive minor suggestions | Overly positive without constructive feedback OR overly critical despite strong design | Imbalanced evaluation | 0.5 |

**Expected Key Behaviors:**
- Recognize and explicitly state that this is a well-designed perspective
- Confirm that all 5 scope items have corresponding problem bank coverage
- Validate that "missing element" type issues are present (REL-001, REL-002, REL-003)
- Provide 1-2 minor enhancement suggestions (e.g., add disaster recovery, add chaos engineering)
- Maintain balanced tone: acknowledge strengths while providing constructive feedback

**Anti-patterns:**
- Forcing critical issues where none exist
- Failing to acknowledge well-designed elements
- Providing only positive feedback without any constructive suggestions
- Missing the validation of missing element detection capability despite strong problem bank

---

### T07: Best Practices Perspective with Duplicate Detection Risk

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T07-C1 | Critical Overlap Identification | Identifies that "Security Best Practices" and "Performance Optimization" are entire domains covered by dedicated perspectives, creating high risk of duplicate/conflicting reviews | Mentions overlap but does not emphasize criticality | Does not identify overlap issue | 1.0 |
| T07-C2 | Scope Redefinition Proposal | Proposes complete removal of security and performance from scope OR proposes clear delineation (e.g., "Security: only non-security-specific best practices like input validation naming") | Vague suggestion to "narrow scope" without specifics | No scope redefinition proposal | 1.0 |
| T07-C3 | Problem Bank Conflict Analysis | Identifies that BP-002 (SQL injection) directly conflicts with security perspective's responsibility, proposes removal or transfer | Mentions problem conflicts without specific action | Does not analyze problem bank conflicts | 1.0 |
| T07-C4 | "Best Practices" Definition Clarity | Points out that "Best Practices" is ill-defined (what qualifies as "best practice"?) and proposes either renaming perspective or defining clear boundaries | Mentions ambiguity without actionable proposal | Does not identify definition issue | 1.0 |
| T07-C5 | Missing Element Detection Impact | Evaluates how overlap affects missing element detection (e.g., if both security and best practices perspectives check for SQL injection, which one reports the omission?) | Brief mention without analysis | Does not evaluate detection impact | 0.5 |
| T07-C6 | Alternative Focus Proposal | Proposes alternative focus for "Best Practices" perspective (e.g., "Code Craftsmanship: readability, simplicity, expressiveness" excluding security/performance/architecture) | General suggestion without concrete alternative | No alternative proposal | 1.0 |

**Expected Key Behaviors:**
- Identify critical overlap with security and performance perspectives
- Propose removing security and performance from scope entirely
- Highlight specific problem bank items that conflict (BP-002 with security, BP-006 with performance)
- Question the value of a "Best Practices" meta-perspective vs. focused domain perspectives
- Propose either clear boundaries or recommend merging into other perspectives
- Evaluate risk of duplicate/conflicting feedback in multi-perspective review

**Anti-patterns:**
- Accepting overlap as "natural" or "acceptable"
- Suggesting coordination between perspectives rather than addressing root cause
- Missing the critical issue: one perspective's entire scope is another's subdomain
- Focusing only on minor issues while missing structural problem
- Not questioning whether "Best Practices" perspective should exist in current form

---

### T08: Data Modeling Perspective with Edge Case Scenarios

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T08-C1 | Missing Temporal Data Handling | Identifies that temporal data (timestamps, versioning, soft deletes) is completely absent from scope and problem bank despite being essential for data modeling | Mentions temporal data briefly without emphasizing omission | Does not identify temporal data gap | 1.0 |
| T08-C2 | Missing Element Detection Table | Provides 5+ essential data modeling elements (e.g., audit columns, soft delete flags, timezone handling, data archival strategy, cascade behaviors) with detectability analysis | Lists 3-4 elements OR incomplete analysis | Fewer than 3 elements or no analysis | 1.0 |
| T08-C3 | Problem Bank Additions | Proposes 3+ specific "missing element" problems related to temporal data, audit trails, and data lifecycle (e.g., "DM-009 (Critical): No created_at/updated_at audit columns", "DM-010 (Moderate): No soft delete mechanism") | Proposes 1-2 problems OR vague descriptions | No specific problem proposals | 1.0 |
| T08-C4 | Edge Case Coverage | Identifies that problem bank lacks edge cases like "handling NULL in unique constraints", "orphaned records on cascade delete", "timezone inconsistencies" | Mentions edge cases generally without specifics | Does not evaluate edge case coverage | 0.5 |
| T08-C5 | Severity Distribution | Confirms appropriate distribution (3 critical, 4 moderate, 1 minor) and notes that additional critical issues should be added for temporal data | Notes distribution without improvement proposal | Does not evaluate severity distribution | 0.5 |

**Expected Key Behaviors:**
- Detect absence of temporal data handling (timestamps, versioning, soft deletes) as critical gap
- Identify missing audit trail requirements (created_by, updated_by columns)
- Propose specific additions: "Add 'Temporal Data and Audit Trails' as scope item 6"
- Add problems: "No audit columns", "No soft delete mechanism", "No timezone handling"
- Recognize that current problem bank focuses on structure but misses data lifecycle concerns

**Anti-patterns:**
- Evaluating only present elements without detecting critical absences
- Missing temporal data gap despite it being fundamental to data modeling
- Proposing generic "add more problems" without specific domain focus
- Not considering data lifecycle (creation, modification, deletion, archival)

---

## Summary Statistics

**Total Scenarios**: 8
**Total Criteria**: 30

**Criteria by Weight**:
- Weight 1.0: 24 criteria (80%)
- Weight 0.5: 6 criteria (20%)

**Difficulty Distribution**:
- Easy: 2 scenarios (T01, T06)
- Medium: 4 scenarios (T02, T03, T05, T08)
- Hard: 2 scenarios (T04, T07)

**Capability Coverage**:
- Missing Element Detection: T02, T04, T05, T06, T08
- Scope Coverage Analysis: T01, T03, T05, T07
- Problem Bank Quality: T01, T02, T04, T08
- Critical Issue Identification: T05, T07
- Actionability: T01, T03
- Positive Evaluation: T06

---

## Scoring Calculation

For each scenario:
1. Calculate raw score: Σ(criterion_score × weight)
2. Calculate max possible: Σ(2 × weight)
3. Normalize: (raw_score / max_possible) × 100

**Example (T01)**:
- C1 (weight 1.0): Full (2) = 2.0
- C2 (weight 1.0): Partial (1) = 1.0
- C3 (weight 0.5): Full (2) = 1.0
- C4 (weight 1.0): Miss (0) = 0.0
- Raw score: 4.0
- Max possible: (1.0 + 1.0 + 0.5 + 1.0) × 2 = 7.0
- Normalized: (4.0 / 7.0) × 100 = 57.14%

---
