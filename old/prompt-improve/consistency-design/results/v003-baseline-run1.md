# Consistency Review Report: Real-time Streaming Platform

**Review Date**: 2026-02-11
**Document**: リアルタイム配信プラットフォーム システム設計書
**Reviewer**: consistency-design-reviewer (v003-baseline)

---

## Overall Structure Analysis

The design document provides comprehensive coverage across seven main sections: overview, technology stack, architecture design, data models, API design, implementation guidelines, and non-functional requirements. The document presents sufficient information for consistency evaluation in most areas, though some critical pattern documentation is missing.

**Key Observations**:
- Technology stack choices (Spring Boot, React, PostgreSQL, Redis) are clearly stated
- Architectural layer structure is explicitly defined (Presentation/Business/Data Access)
- Data models, API endpoints, and error handling approaches are documented
- Missing: explicit documentation of existing codebase patterns that informed these design decisions

---

## Inconsistencies Identified

### CRITICAL: Database Naming Convention Inconsistency

**Severity**: Critical
**Category**: Naming Convention Consistency

**Issue**: The three database tables use fundamentally inconsistent naming conventions:
- `live_stream`: snake_case table name, snake_case column names
- `ChatMessage`: PascalCase table name, camelCase column names
- `viewer_sessions`: snake_case table name, snake_case column names

**Evidence**: Lines 80-114 in the data model section demonstrate this inconsistency across all three CREATE TABLE statements.

**Impact**:
- Database queries will require mixed case handling strategies
- ORM mapping configuration becomes fragmented (different @Table/@Column annotations)
- Future developers cannot determine which convention to follow
- Schema migration scripts will lack consistency
- Database tooling may treat these differently (case-sensitivity issues)

**Consistency Verification Gap**: The design document does not reference existing database naming patterns in the codebase, making it impossible to determine which convention aligns with established practice.

---

### CRITICAL: Missing Architectural Pattern Documentation

**Severity**: Critical
**Category**: Architecture Pattern Consistency

**Issue**: The document states "既存システムのレイヤー構成に従い" (following existing system layer structure) but does not document:
- How the existing system handles cross-cutting concerns (transaction boundaries, exception propagation)
- Whether the existing system uses a pure 3-layer architecture or includes additional layers (e.g., application service layer, facade pattern)
- How WebSocket handlers integrate with the existing layered architecture
- Whether the existing system separates domain models from entities

**Evidence**: Section 3 (Architecture Design) references alignment with existing patterns but provides no verification mechanism.

**Impact**:
- Developers cannot verify if `ChatWebSocketHandler` placement in Presentation layer matches existing real-time communication patterns
- Transaction boundary decisions (Service vs Repository level) may conflict with existing approaches
- Domain model design (lines 48-66) may duplicate or contradict existing entity structures

---

### SIGNIFICANT: Error Handling Pattern Inconsistency Risk

**Severity**: Significant
**Category**: Implementation Pattern Consistency

**Issue**: The document specifies "Controller層の個別 catch ブロックで処理する" (handle in individual catch blocks at Controller layer), which contradicts common Spring Boot practice of centralized `@ControllerAdvice` exception handling.

**Evidence**: Line 175 explicitly states individual catch block approach.

**Consistency Verification Gap**: No reference to existing error handling patterns. If the existing codebase uses `@ControllerAdvice` or `@ExceptionHandler`, this design would create inconsistency.

**Impact**:
- Duplicated error handling logic across multiple controllers
- Inconsistent error response formats if each controller handles exceptions independently
- Maintenance burden when updating error handling behavior
- Potential deviation from existing REST API error contracts

**Recommendation**: Document whether existing codebase uses global exception handlers or individual catch blocks, and provide justification if diverging from established pattern.

---

### SIGNIFICANT: API Response Format Inconsistency

**Severity**: Significant
**Category**: API/Interface Design Consistency

**Issue**: The proposed API response wraps data in a `success` boolean + `stream` or `error` object structure (lines 147-166). This wrapper pattern should be verified against existing API response formats in the codebase.

**Evidence**:
```json
{
  "success": true,
  "stream": { ... }
}
```

**Consistency Questions**:
- Do existing APIs use this success/error wrapper pattern?
- Or do they use HTTP status codes + direct response bodies?
- Do existing APIs nest resource data under a named key (`stream`) or return it at root level?

**Impact**: If existing APIs use different response structures, client-side code will require multiple response parsing strategies, and API documentation will lack consistency.

---

### SIGNIFICANT: Logging Format Specification Without Context

**Severity**: Significant
**Category**: Implementation Pattern Consistency

**Issue**: A specific logging format is prescribed (line 179-181) without verification that this matches existing logging patterns:

```
[LEVEL] [YYYY-MM-DD HH:MM:SS] [ClassName.methodName] - Log message (key1=value1, key2=value2)
```

**Consistency Verification Gap**:
- Does the existing codebase use structured logging (JSON format)?
- What logging framework is currently in use (Logback, Log4j2)?
- Are there existing log correlation IDs or trace IDs in the format?

**Impact**: If existing logs use JSON structured format with MDC context, this plain-text format would:
- Break log aggregation queries in monitoring systems
- Lose correlation with existing application logs
- Prevent unified log analysis across modules

---

### MODERATE: File Placement Documentation Missing

**Severity**: Moderate
**Category**: Directory Structure & File Placement Consistency

**Issue**: The document specifies class names but does not specify package structure or file placement strategy.

**Missing Information**:
- Package organization: domain-based (`com.example.livestream.service`) vs layer-based (`com.example.service.livestream`)?
- WebSocket handler placement: separate package or within controller package?
- Repository interface placement: co-located with entities or in separate package?

**Impact**: Implementation phase will require ad-hoc decisions that may not align with existing codebase organization patterns.

---

### MODERATE: Dependency Version Alignment Not Verified

**Severity**: Moderate
**Category**: API/Interface Design & Dependency Consistency

**Issue**: Technology stack versions are specified (Java 17, Spring Boot 3.2, PostgreSQL 15, etc.) without verification that these align with existing system dependencies.

**Evidence**: Section 2 lists specific versions but does not reference existing dependency constraints.

**Consistency Questions**:
- Does the existing system already use Java 17 and Spring Boot 3.2?
- Are there shared parent POM or dependency management configurations?
- Do existing modules use different PostgreSQL versions?

**Impact**: Version conflicts in multi-module projects, incompatible library versions, or forced migration of existing modules.

---

### MODERATE: Configuration File Format Not Specified

**Severity**: Moderate
**Category**: API/Interface Design & Dependency Consistency

**Issue**: No specification of configuration file format (application.yml vs application.properties) or environment variable naming conventions.

**Missing Information**:
- Configuration format preference (YAML vs Properties)
- Environment variable prefix conventions
- Configuration profile naming strategy

**Impact**: Inconsistent configuration management if different modules use different formats.

---

## Pattern Evidence

**NOTE**: Due to the absence of Java/TypeScript source files in the target codebase directory, pattern evidence is based on consistency analysis of the design document itself and general Spring Boot/React ecosystem conventions.

### Expected Patterns (Industry Standard for Spring Boot + React):

1. **Database Naming**: PostgreSQL with Spring Boot typically uses snake_case for tables and columns
2. **Error Handling**: Modern Spring Boot applications typically use `@ControllerAdvice` for centralized exception handling
3. **API Responses**: RESTful APIs often return resources directly with HTTP status codes rather than wrapper objects
4. **Logging**: Spring Boot 3.x commonly uses Logback with JSON structured logging for production systems
5. **Configuration**: Spring Boot projects typically use `application.yml` for hierarchical configuration

**Verification Limitation**: Cannot verify which patterns the existing codebase actually uses without access to source files.

---

## Impact Analysis

### High Impact Inconsistencies:

1. **Database Naming Fragmentation**: Immediate impact on all database interactions, ORM configurations, and schema management. Requires decision and standardization before implementation begins.

2. **Architectural Pattern Gaps**: Risk of duplicating existing functionality or creating incompatible abstractions. May require significant refactoring if discovered late in implementation.

3. **Error Handling Divergence**: If inconsistent with existing approach, will create dual maintenance paths and inconsistent error contracts across the API surface.

### Medium Impact Inconsistencies:

4. **API Response Structure**: Client-side impact requiring conditional response parsing. Can be mitigated with adapter layers but increases complexity.

5. **Logging Format Mismatch**: Operational impact on monitoring, alerting, and debugging workflows. Harder to detect during development.

### Low Impact Inconsistencies:

6. **File Placement Variability**: Primarily affects code navigation and onboarding. Can be corrected via refactoring with low risk.

---

## Recommendations

### Immediate Actions (Before Implementation):

1. **Standardize Database Naming**:
   - Survey existing database schema naming conventions
   - Document the dominant pattern (snake_case expected)
   - Update all three table definitions to use consistent convention
   - Recommended: `live_stream`, `chat_message`, `viewer_session` with all snake_case columns

2. **Document Existing Architectural Patterns**:
   - Add a section "Alignment with Existing Architecture" that references:
     - Existing layer structure examples (file paths to similar features)
     - Transaction boundary patterns in existing Services
     - How existing code handles real-time/async features
   - Explicitly state if this design introduces new patterns and justify why

3. **Verify and Document Error Handling Pattern**:
   - Check existing Controller implementations for exception handling approach
   - If existing code uses `@ControllerAdvice`, update design to follow that pattern
   - If individual catch blocks are truly the standard, provide examples from existing code

### High Priority Actions:

4. **Verify API Response Format**:
   - Reference existing API endpoints and their response structures
   - If wrapper pattern is new, document migration strategy for consistency
   - Recommend: Align with existing pattern unless there is strong justification for change

5. **Document Logging Infrastructure**:
   - Identify existing logging framework and format
   - Update logging specification to match existing structure
   - Include MDC/trace ID requirements if present in existing system

### Medium Priority Actions:

6. **Specify Package Structure**:
   - Add a section documenting package organization strategy
   - Provide example file paths for each component
   - Reference existing module structure

7. **Verify Dependency Versions**:
   - Add a subsection confirming alignment with existing dependency versions
   - Document any version upgrades and their justification
   - Reference parent POM or dependency management configuration

8. **Specify Configuration Format**:
   - Document configuration file format and naming conventions
   - Provide examples of key configuration properties
   - Reference existing configuration structure

---

## Positive Alignment Aspects

The design document demonstrates strong alignment in several areas:

1. **Explicit Technology Stack**: Clear specification of frameworks and versions enables consistency verification
2. **Layer Structure Declaration**: Explicit statement of following existing 3-layer architecture shows awareness of consistency requirements
3. **Component Naming**: Service and Repository naming follows standard Spring Boot conventions
4. **API Versioning**: Use of `/api/v1/` prefix suggests alignment with versioned API strategy
5. **JWT Authentication Reference**: Explicit statement of reusing existing authentication mechanism demonstrates integration awareness

---

## Summary

This design document provides a solid foundation but has **3 critical consistency gaps** that must be resolved before implementation:

1. **Database naming inconsistency** (ChatMessage table) - requires immediate standardization
2. **Missing architectural pattern documentation** - prevents verification of alignment
3. **Error handling approach** - may conflict with existing centralized exception handling

Additionally, **5 significant consistency questions** require verification against the existing codebase:
- API response format alignment
- Logging format compatibility
- Package/file organization strategy
- Dependency version consistency
- Configuration format conventions

**Recommended Next Step**: Conduct a codebase pattern survey focusing on the eight consistency gaps identified above, then update the design document with explicit references to existing patterns before proceeding to implementation.
