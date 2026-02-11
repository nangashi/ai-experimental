# Test Scenario Set: critic-completeness

Agent: critic-completeness
Version: v001-baseline
Generated: 2026-02-11

---

## Test Scenarios

### T01: Well-Structured Security Perspective with Minor Gaps

**Difficulty**: Easy
**Category**: Scope Coverage Analysis

#### Input

```markdown
# Security Design Reviewer

## Evaluation Scope

1. **Authentication and Authorization Design** - Identity verification mechanisms, access control policies, role-based access control
2. **Data Protection** - Encryption at rest and in transit, sensitive data handling, PII protection
3. **Input Validation and Sanitization** - SQL injection prevention, XSS protection, command injection prevention
4. **Security Logging and Monitoring** - Audit trails, security event logging, anomaly detection
5. **Third-party Dependencies** - Dependency vulnerability scanning, supply chain security

## Problem Bank

| ID | Severity | Problem | Evidence Keywords |
|----|----------|---------|-------------------|
| SEC-001 | Critical | No authentication mechanism defined | "no auth", "unauthenticated access" |
| SEC-002 | Critical | Plaintext storage of sensitive data | "plaintext password", "unencrypted credentials" |
| SEC-003 | Critical | Direct SQL query construction from user input | "string concatenation in query", "no parameterization" |
| SEC-004 | Moderate | Insufficient access control granularity | "all-or-nothing access", "no role separation" |
| SEC-005 | Moderate | Missing encryption for data in transit | "http instead of https", "no TLS" |
| SEC-006 | Moderate | Inadequate logging of security events | "no audit trail", "authentication failures not logged" |
| SEC-007 | Minor | Outdated dependencies with known CVEs | "old version", "unpatched library" |
| SEC-008 | Minor | Weak password policy | "no complexity requirement", "short password allowed" |
```

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T01-C1 | Scope Coverage Completeness | Identifies that scope adequately covers security domain with only minor gaps (e.g., session management, rate limiting) | Mentions scope is generally adequate but misses specific gap analysis | Does not evaluate scope coverage systematically | 1.0 |
| T01-C2 | Missing Element Detection Analysis | Provides 5+ essential security design elements and evaluates detectability for each | Lists 3-4 elements OR evaluates detectability superficially | Lists fewer than 3 elements or no detectability analysis | 1.0 |
| T01-C3 | Problem Bank Severity Distribution | Notes that severity distribution is appropriate (3 critical, 3 moderate, 2 minor) | Mentions severity distribution without quantitative analysis | Does not evaluate severity distribution | 0.5 |
| T01-C4 | Actionable Improvement Proposals | Proposes 2-3 specific additions (e.g., "add session management to scope", "add rate limiting issue to problem bank") | Proposes 1 improvement OR proposals are vague | No concrete proposals | 1.0 |

#### Expected Key Behaviors
- Recognize that the perspective is well-structured with adequate coverage
- Identify minor gaps (e.g., session management, rate limiting, CSRF protection)
- Confirm that problem bank includes "missing element" type issues (SEC-001, SEC-002, SEC-003)
- Provide specific, actionable recommendations for minor improvements

#### Anti-patterns
- Overly critical evaluation of a fundamentally sound perspective
- Vague feedback like "add more security concerns" without specifics
- Missing the distinction between critical/moderate/minor severity
- Failing to acknowledge well-designed elements

---

### T02: Performance Perspective Missing Critical Detection Capability

**Difficulty**: Medium
**Category**: Missing Element Detection

#### Input

```markdown
# Performance Design Reviewer

## Evaluation Scope

1. **Algorithm Complexity** - Time complexity analysis, space complexity, optimization opportunities
2. **Database Query Efficiency** - Index usage, N+1 query problems, query optimization
3. **Resource Utilization** - Memory usage, CPU utilization, connection pooling
4. **Scalability Considerations** - Horizontal vs vertical scaling, bottleneck identification
5. **Frontend Performance** - Bundle size, lazy loading, rendering optimization

## Problem Bank

| ID | Severity | Problem | Evidence Keywords |
|----|----------|---------|-------------------|
| PERF-001 | Critical | O(n²) algorithm in critical path | "nested loop", "quadratic complexity" |
| PERF-002 | Critical | Missing database indexes on frequently queried columns | "full table scan", "no index on join column" |
| PERF-003 | Moderate | Large bundle size affecting load time | "bundle size > 1MB", "no code splitting" |
| PERF-004 | Moderate | Inefficient resource allocation | "creating new connection per request", "no connection pooling" |
| PERF-005 | Moderate | Synchronous operations blocking main thread | "blocking I/O in UI thread", "no async/await" |
| PERF-006 | Minor | Redundant computations | "recalculating same value", "no memoization" |
```

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T02-C1 | Detection of Missing Caching Strategy | Identifies that "caching" is completely absent from evaluation scope and problem bank, with specific proposal to add it | Mentions caching briefly but without specific addition proposal | Does not identify caching as missing critical element | 1.0 |
| T02-C2 | Missing Element Detection Table | Provides table with 5+ essential performance elements (e.g., caching, rate limiting, lazy loading, data pagination) and detectability analysis for each | Provides 3-4 elements OR incomplete detectability analysis | Fewer than 3 elements or no structured analysis | 1.0 |
| T02-C3 | Problem Bank Gap Identification | Identifies that problem bank lacks "missing cache" or "no pagination" type issues, proposes specific additions | Mentions problem bank gaps generally without specific proposals | Does not evaluate problem bank coverage | 1.0 |
| T02-C4 | Severity Distribution Assessment | Notes insufficient critical issues (only 2) and proposes elevation or addition | Mentions severity imbalance without specific action | Does not evaluate severity distribution | 0.5 |

#### Expected Key Behaviors
- Detect that caching is a critical performance element completely absent from scope and problem bank
- Identify other missing critical elements (e.g., pagination for large datasets, rate limiting, lazy evaluation)
- Propose specific additions: "Add 'Caching Strategy' as scope item 6" and "Add PERF-007 (Critical): No caching mechanism for frequently accessed data"
- Evaluate whether AI reviewer following this perspective could detect "design with no caching" (answer: NO)

#### Anti-patterns
- Focusing only on present elements without detecting absent critical elements
- Vague statements like "could add more performance concerns"
- Failing to distinguish between "nice to have" and "critical missing element"
- Not using the missing element detection framework

---

### T03: Consistency Perspective with Ambiguous Scope Items

**Difficulty**: Medium
**Category**: Scope Coverage Analysis + Actionability

#### Input

```markdown
# Consistency Design Reviewer

## Evaluation Scope

1. **Naming Conventions** - Variable names, function names, class names consistency
2. **Code Organization** - Module structure, file organization, component hierarchy
3. **Design Patterns** - Pattern usage consistency, architectural style adherence
4. **Error Handling** - Exception handling approach, error message format
5. **Documentation Style** - Comment format, API documentation, inline documentation

## Problem Bank

| ID | Severity | Problem | Evidence Keywords |
|----|----------|---------|-------------------|
| CONS-001 | Critical | Mixing multiple architectural patterns inconsistently | "MVC and MVVM mixed", "inconsistent pattern application" |
| CONS-002 | Moderate | Inconsistent naming conventions across modules | "camelCase and snake_case mixed", "inconsistent variable naming" |
| CONS-003 | Moderate | Mixed error handling approaches | "some functions throw, others return error codes" |
| CONS-004 | Moderate | Inconsistent code organization | "some features in /components, others in /modules" |
| CONS-005 | Minor | Inconsistent comment style | "some JSDoc, some inline comments" |
| CONS-006 | Minor | Variable documentation style differs | "some documented, some undocumented" |
```

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T03-C1 | Overlap with Other Perspectives | Identifies that "Code Organization" and "Design Patterns" overlap significantly with maintainability/architecture perspectives, proposes narrowing scope | Mentions overlap but without specific action | Does not identify scope overlap issue | 1.0 |
| T03-C2 | Ambiguity in Scope Items | Points out that "Naming Conventions" is too broad (spans variables, functions, classes, constants, files, etc.) and proposes more focused definition | Mentions breadth but without actionable proposal | Does not identify ambiguity | 1.0 |
| T03-C3 | Missing Element Detection for Consistency | Identifies missing consistency areas (e.g., API versioning consistency, database schema naming, configuration format consistency) | Lists 1-2 missing areas without detectability analysis | Does not identify missing consistency elements | 1.0 |
| T03-C4 | Problem Bank Improvement | Notes insufficient critical issues (only 1) and proposes specific additions like "No consistent API contract format" or "Mixed configuration formats" | General comment about problem bank without specific proposals | Does not evaluate problem bank | 0.5 |
| T03-C5 | Actionable Scope Refinement | Proposes specific rewording: e.g., "Naming Conventions → Identifier Naming Consistency (variables, functions, classes)" | Suggests refinement without concrete examples | No scope refinement proposal | 1.0 |

#### Expected Key Behaviors
- Identify that "Code Organization" and "Design Patterns" are too broad and overlap with other perspectives
- Propose narrowing scope to consistency-specific aspects (e.g., "consistent application of chosen pattern" rather than "pattern selection")
- Detect missing consistency areas: API contract consistency, schema naming, configuration format
- Provide specific scope item rewording suggestions

#### Anti-patterns
- Accepting overly broad scope items without questioning
- Missing overlap analysis with other perspectives (maintainability, architecture)
- Vague feedback like "clarify scope items"
- Not proposing concrete rewording

---

### T04: Minimal Maintainability Perspective Lacking Examples

**Difficulty**: Hard
**Category**: Problem Bank Quality + Missing Element Detection

#### Input

```markdown
# Maintainability Design Reviewer

## Evaluation Scope

1. **Code Modularity** - Component separation, coupling, cohesion
2. **Extensibility** - Ease of adding new features, modification points
3. **Readability** - Code clarity, self-documenting code
4. **Testing Infrastructure** - Test coverage, test maintainability
5. **Technical Debt Management** - Deprecated code handling, refactoring needs

## Problem Bank

| ID | Severity | Problem | Evidence Keywords |
|----|----------|---------|-------------------|
| MAINT-001 | Critical | Tight coupling between unrelated modules | "circular dependency", "high coupling" |
| MAINT-002 | Moderate | Low code readability | "complex logic", "unclear naming" |
| MAINT-003 | Minor | Missing unit tests | "no test coverage" |
```

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T04-C1 | Problem Bank Insufficiency | Identifies that only 3 problems exist (guideline: 8-12), with severe gaps in coverage of scope items 2, 4, 5 | Notes problem bank is sparse but without quantitative analysis | Does not evaluate problem bank size/coverage | 1.0 |
| T04-C2 | Missing "Should Exist" Type Issues | Identifies that problem bank lacks "missing element" issues (e.g., "No modular architecture", "No extension points defined", "No deprecation policy") and proposes 3+ specific additions | Mentions need for omission-type issues but proposes fewer than 3 | Does not identify this gap | 1.0 |
| T04-C3 | Severity Distribution Problem | Notes that there are insufficient critical (only 1) and moderate (only 1) issues, proposes specific additions or severity adjustments | General comment about severity without specific action | Does not evaluate severity distribution | 0.5 |
| T04-C4 | Missing Element Detection Capability | Evaluates whether AI reviewer could detect "design with no testing strategy" (scope item 4) and concludes NO due to problem bank gap, proposes specific problem addition | Partial analysis without actionable proposal | No missing element detection evaluation | 1.0 |
| T04-C5 | Scope vs Problem Bank Alignment | Identifies that scope items "Extensibility" and "Technical Debt Management" have zero problem bank examples, proposes at least 1 problem per scope item | Notes misalignment but without specific additions | Does not evaluate scope-problem alignment | 1.0 |
| T04-C6 | Evidence Keyword Quality | Points out that evidence keywords are too generic ("complex logic", "unclear naming") and proposes more specific keywords | Mentions keyword quality without proposals | Does not evaluate evidence keywords | 0.5 |

#### Expected Key Behaviors
- Recognize severe problem bank insufficiency (only 3 problems vs. guideline 8-12)
- Identify complete absence of problems for scope items 2 (Extensibility), 5 (Technical Debt Management)
- Propose specific "missing element" type problems: e.g., "MAINT-004 (Critical): No defined extension points or plugin architecture", "MAINT-005 (Moderate): No deprecation policy for legacy code"
- Evaluate missing element detectability and conclude current definition is insufficient
- Provide 5+ specific problem additions with severity, description, and evidence keywords

#### Anti-patterns
- Superficial problem bank evaluation without quantitative analysis
- Missing the critical link between scope items and problem bank coverage
- Proposing generic additions like "add more problems"
- Failing to identify the "missing element detection" gap despite it being the agent's primary responsibility

---

### T05: Architecture Perspective with Conflicting Priorities

**Difficulty**: Medium
**Category**: Critical Issue Identification + Scope Coverage

#### Input

```markdown
# Architecture Design Reviewer

## Evaluation Scope

1. **System Decomposition** - Microservices vs monolith, service boundaries, component separation
2. **Data Flow Architecture** - Event-driven vs request-response, message queues, data pipelines
3. **Technology Stack Selection** - Framework choices, library selection, technology compatibility
4. **Deployment Architecture** - Container orchestration, CI/CD pipeline, infrastructure as code
5. **Cross-cutting Concerns** - Logging, monitoring, tracing, configuration management

## Problem Bank

| ID | Severity | Problem | Evidence Keywords |
|----|----------|---------|-------------------|
| ARCH-001 | Critical | Mixing incompatible architectural styles | "synchronous and event-driven mixed", "inconsistent communication patterns" |
| ARCH-002 | Critical | Service boundaries violate domain boundaries | "shared database across services", "tight coupling between microservices" |
| ARCH-003 | Critical | Technology stack incompatibility | "conflicting framework versions", "incompatible dependencies" |
| ARCH-004 | Moderate | Missing observability infrastructure | "no distributed tracing", "no centralized logging" |
| ARCH-005 | Moderate | Inadequate deployment automation | "manual deployment steps", "no CI/CD pipeline" |
| ARCH-006 | Moderate | Configuration management issues | "hardcoded configuration", "no environment separation" |
| ARCH-007 | Minor | Overly complex architecture for simple requirements | "microservices for small app", "unnecessary abstraction layers" |
| ARCH-008 | Minor | Missing documentation for architecture decisions | "no ADRs", "undocumented design rationale" |
```

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T05-C1 | Technology Stack Scope Concern | Identifies that "Technology Stack Selection" is overly broad and overlaps with security, performance, and maintainability perspectives (e.g., framework performance, security vulnerabilities in libraries) | Mentions overlap without specific analysis | Does not identify scope issue | 1.0 |
| T05-C2 | Missing Element Detection | Provides 5+ essential architecture elements (e.g., API gateway, service mesh, caching layer, authentication service) and evaluates detectability | Lists 3-4 elements OR incomplete detectability analysis | Fewer than 3 elements or no analysis | 1.0 |
| T05-C3 | Scope Refinement Proposal | Proposes narrowing "Technology Stack Selection" to architecture-specific aspects (e.g., "Architectural Pattern Implementation - Framework support for chosen patterns, technology alignment with architectural style") | Suggests refinement without concrete rewording | No refinement proposal | 1.0 |
| T05-C4 | Problem Bank Coverage | Notes that "System Decomposition" (scope item 1) lacks "missing element" type problems (e.g., "No defined service boundaries", "Monolith without clear module separation") and proposes additions | General comment without specific additions | Does not evaluate problem bank coverage | 1.0 |

#### Expected Key Behaviors
- Identify that "Technology Stack Selection" is too broad and infringes on other perspectives' domains
- Propose scope refinement to focus on architecture-specific technology concerns
- Detect missing architecture elements: API gateway, service mesh, caching architecture, authentication/authorization infrastructure
- Recognize good severity distribution and problem bank diversity
- Balance critical feedback with acknowledgment of well-structured elements

#### Anti-patterns
- Accepting broad scope items that overlap with other perspectives
- Missing the distinction between "technology choice" (broad) and "technology alignment with architecture" (focused)
- Failing to propose concrete scope rewording
- Only providing negative feedback without acknowledging strong aspects

---

### T06: Reliability Perspective with Strong Detection Capability

**Difficulty**: Easy
**Category**: Positive Evaluation + Minor Improvements

#### Input

```markdown
# Reliability Design Reviewer

## Evaluation Scope

1. **Fault Tolerance** - Graceful degradation, fallback mechanisms, circuit breakers
2. **Error Recovery** - Retry logic, idempotency, transaction rollback
3. **Data Integrity** - Consistency guarantees, validation, constraint enforcement
4. **Availability Design** - Redundancy, failover, health checks
5. **Monitoring and Alerting** - Error rate tracking, SLA monitoring, incident detection

## Evaluation Scope

1. **Fault Tolerance** - Graceful degradation, fallback mechanisms, circuit breakers
2. **Error Recovery** - Retry logic, idempotency, transaction rollback
3. **Data Integrity** - Consistency guarantees, validation, constraint enforcement
4. **Availability Design** - Redundancy, failover, health checks
5. **Monitoring and Alerting** - Error rate tracking, SLA monitoring, incident detection

## Problem Bank

| ID | Severity | Problem | Evidence Keywords |
|----|----------|---------|-------------------|
| REL-001 | Critical | No circuit breaker for external service calls | "direct call to external API", "no failure handling" |
| REL-002 | Critical | Missing idempotency in critical operations | "duplicate processing possible", "no idempotency key" |
| REL-003 | Critical | No data validation at system boundaries | "unvalidated input persisted", "no constraint checks" |
| REL-004 | Moderate | Inadequate retry logic | "single attempt only", "no exponential backoff" |
| REL-005 | Moderate | Missing fallback mechanism | "no degraded mode", "fails completely on dependency failure" |
| REL-006 | Moderate | Insufficient health check coverage | "health check only for web server", "database health not monitored" |
| REL-007 | Moderate | No alerting on SLA violations | "error tracking exists but no alerts", "manual monitoring required" |
| REL-008 | Minor | Inconsistent error logging | "some errors logged, others not" |
| REL-009 | Minor | Missing transaction boundaries | "partial updates possible", "no atomic operations" |
```

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T06-C1 | Recognition of Strong Design | Explicitly acknowledges that the perspective is well-designed with good scope coverage, appropriate severity distribution (3 critical, 4 moderate, 2 minor), and strong missing element detection capability | Acknowledges some strengths without comprehensive evaluation | Does not acknowledge strengths | 1.0 |
| T06-C2 | Missing Element Detection Validation | Provides 5+ essential reliability elements and confirms detectability for each, concluding that the perspective enables effective omission detection | Lists 3-4 elements OR incomplete confirmation of detectability | Fewer than 3 elements or no detectability validation | 1.0 |
| T06-C3 | Minor Improvement Identification | Identifies 1-2 minor enhancements despite overall strong design (e.g., "Add disaster recovery to scope", "Add chaos engineering testing to problem bank") | Vague suggestions without specifics | States "no improvements needed" without thorough analysis | 0.5 |
| T06-C4 | Balanced Evaluation | Provides balanced report emphasizing positive aspects while including constructive minor suggestions | Overly positive without constructive feedback OR overly critical despite strong design | Imbalanced evaluation | 0.5 |

#### Expected Key Behaviors
- Recognize and explicitly state that this is a well-designed perspective
- Confirm that all 5 scope items have corresponding problem bank coverage
- Validate that "missing element" type issues are present (REL-001, REL-002, REL-003)
- Provide 1-2 minor enhancement suggestions (e.g., add disaster recovery, add chaos engineering)
- Maintain balanced tone: acknowledge strengths while providing constructive feedback

#### Anti-patterns
- Forcing critical issues where none exist
- Failing to acknowledge well-designed elements
- Providing only positive feedback without any constructive suggestions
- Missing the validation of missing element detection capability despite strong problem bank

---

### T07: Best Practices Perspective with Duplicate Detection Risk

**Difficulty**: Hard
**Category**: Scope Coverage + Critical Issue Identification

#### Input

```markdown
# Best Practices Design Reviewer

## Evaluation Scope

1. **Code Quality Standards** - Clean code principles, SOLID principles, DRY, KISS
2. **Security Best Practices** - OWASP Top 10, secure coding guidelines, principle of least privilege
3. **Performance Optimization** - Premature optimization avoidance, profiling-driven optimization
4. **Error Handling Best Practices** - Exception hierarchy, error propagation, graceful degradation
5. **Documentation Standards** - README quality, API documentation, code comments

## Problem Bank

| ID | Severity | Problem | Evidence Keywords |
|----|----------|---------|-------------------|
| BP-001 | Critical | Violation of SOLID principles | "god class", "tight coupling", "SRP violation" |
| BP-002 | Critical | Security vulnerability (SQL injection) | "string concatenation in query", "no parameterization" |
| BP-003 | Moderate | Code duplication across modules | "copy-pasted code", "DRY violation" |
| BP-004 | Moderate | Missing error handling | "unhandled exceptions", "no try-catch" |
| BP-005 | Moderate | Inadequate documentation | "no API docs", "missing README" |
| BP-006 | Minor | Premature optimization | "complex optimization without profiling" |
| BP-007 | Minor | Inconsistent code style | "mixed indentation", "inconsistent formatting" |
```

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T07-C1 | Critical Overlap Identification | Identifies that "Security Best Practices" and "Performance Optimization" are entire domains covered by dedicated perspectives, creating high risk of duplicate/conflicting reviews | Mentions overlap but does not emphasize criticality | Does not identify overlap issue | 1.0 |
| T07-C2 | Scope Redefinition Proposal | Proposes complete removal of security and performance from scope OR proposes clear delineation (e.g., "Security: only non-security-specific best practices like input validation naming") | Vague suggestion to "narrow scope" without specifics | No scope redefinition proposal | 1.0 |
| T07-C3 | Problem Bank Conflict Analysis | Identifies that BP-002 (SQL injection) directly conflicts with security perspective's responsibility, proposes removal or transfer | Mentions problem conflicts without specific action | Does not analyze problem bank conflicts | 1.0 |
| T07-C4 | "Best Practices" Definition Clarity | Points out that "Best Practices" is ill-defined (what qualifies as "best practice"?) and proposes either renaming perspective or defining clear boundaries | Mentions ambiguity without actionable proposal | Does not identify definition issue | 1.0 |
| T07-C5 | Missing Element Detection Impact | Evaluates how overlap affects missing element detection (e.g., if both security and best practices perspectives check for SQL injection, which one reports the omission?) | Brief mention without analysis | Does not evaluate detection impact | 0.5 |
| T07-C6 | Alternative Focus Proposal | Proposes alternative focus for "Best Practices" perspective (e.g., "Code Craftsmanship: readability, simplicity, expressiveness" excluding security/performance/architecture) | General suggestion without concrete alternative | No alternative proposal | 1.0 |

#### Expected Key Behaviors
- Identify critical overlap with security and performance perspectives
- Propose removing security and performance from scope entirely
- Highlight specific problem bank items that conflict (BP-002 with security, BP-006 with performance)
- Question the value of a "Best Practices" meta-perspective vs. focused domain perspectives
- Propose either clear boundaries or recommend merging into other perspectives
- Evaluate risk of duplicate/conflicting feedback in multi-perspective review

#### Anti-patterns
- Accepting overlap as "natural" or "acceptable"
- Suggesting coordination between perspectives rather than addressing root cause
- Missing the critical issue: one perspective's entire scope is another's subdomain
- Focusing only on minor issues while missing structural problem
- Not questioning whether "Best Practices" perspective should exist in current form

---

### T08: Data Modeling Perspective with Edge Case Scenarios

**Difficulty**: Medium
**Category**: Missing Element Detection + Problem Bank Quality

#### Input

```markdown
# Data Modeling Design Reviewer

## Evaluation Scope

1. **Schema Design** - Normalization, denormalization trade-offs, entity relationships
2. **Data Type Selection** - Appropriate types for data, precision considerations
3. **Constraint Definition** - Primary keys, foreign keys, unique constraints, check constraints
4. **Indexing Strategy** - Index selection, composite indexes, covering indexes
5. **Migration Management** - Schema versioning, backward compatibility

## Problem Bank

| ID | Severity | Problem | Evidence Keywords |
|----|----------|---------|-------------------|
| DM-001 | Critical | Missing primary key constraint | "no primary key", "no unique identifier" |
| DM-002 | Critical | Foreign key references non-indexed column | "foreign key without index", "unindexed reference" |
| DM-003 | Critical | Data type mismatch for domain | "string for numeric data", "incorrect precision" |
| DM-004 | Moderate | Over-normalization affecting performance | "excessive joins required", "5NF for transactional data" |
| DM-005 | Moderate | Missing indexes on frequently filtered columns | "no index on WHERE clause columns" |
| DM-006 | Moderate | Non-nullable columns without default values | "NOT NULL without DEFAULT" |
| DM-007 | Moderate | Backward-incompatible schema changes | "dropping column in migration", "no data preservation" |
| DM-008 | Minor | Suboptimal index type | "B-tree for range queries on text" |
```

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T08-C1 | Missing Temporal Data Handling | Identifies that temporal data (timestamps, versioning, soft deletes) is completely absent from scope and problem bank despite being essential for data modeling | Mentions temporal data briefly without emphasizing omission | Does not identify temporal data gap | 1.0 |
| T08-C2 | Missing Element Detection Table | Provides 5+ essential data modeling elements (e.g., audit columns, soft delete flags, timezone handling, data archival strategy, cascade behaviors) with detectability analysis | Lists 3-4 elements OR incomplete analysis | Fewer than 3 elements or no analysis | 1.0 |
| T08-C3 | Problem Bank Additions | Proposes 3+ specific "missing element" problems related to temporal data, audit trails, and data lifecycle (e.g., "DM-009 (Critical): No created_at/updated_at audit columns", "DM-010 (Moderate): No soft delete mechanism") | Proposes 1-2 problems OR vague descriptions | No specific problem proposals | 1.0 |
| T08-C4 | Edge Case Coverage | Identifies that problem bank lacks edge cases like "handling NULL in unique constraints", "orphaned records on cascade delete", "timezone inconsistencies" | Mentions edge cases generally without specifics | Does not evaluate edge case coverage | 0.5 |
| T08-C5 | Severity Distribution | Confirms appropriate distribution (3 critical, 4 moderate, 1 minor) and notes that additional critical issues should be added for temporal data | Notes distribution without improvement proposal | Does not evaluate severity distribution | 0.5 |

#### Expected Key Behaviors
- Detect absence of temporal data handling (timestamps, versioning, soft deletes) as critical gap
- Identify missing audit trail requirements (created_by, updated_by columns)
- Propose specific additions: "Add 'Temporal Data and Audit Trails' as scope item 6"
- Add problems: "No audit columns", "No soft delete mechanism", "No timezone handling"
- Recognize that current problem bank focuses on structure but misses data lifecycle concerns

#### Anti-patterns
- Evaluating only present elements without detecting critical absences
- Missing temporal data gap despite it being fundamental to data modeling
- Proposing generic "add more problems" without specific domain focus
- Not considering data lifecycle (creation, modification, deletion, archival)

---
