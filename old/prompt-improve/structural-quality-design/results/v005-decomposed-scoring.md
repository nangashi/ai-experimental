# Scoring Result: variant-decomposed (M1a)

## Run 1 Detection Matrix

| Problem ID | Status | Score | Evidence |
|-----------|--------|-------|----------|
| P01: PropertyManagementService SRP violation | ○ | 1.0 | Section "Critical Issues → 1. Massive SRP Violation" explicitly identifies PropertyManagementService handling "property CRUD, customer matching, appointment management, contract status updates, and statistics aggregation - at least 5 distinct responsibilities" and proposes decomposition into separate services |
| P02: NotificationService external dependency coupling | ○ | 1.0 | Section "Critical Issues → 5. No Dependency Abstraction for External Services" identifies "NotificationService contains hardcoded SMTP host and SMS API key" and recommends interface abstraction (EmailProvider, SMSProvider) |
| P03: Data model redundancy and integrity risk | ○ | 1.0 | Section "Critical Issues → 4. Data Model Violates Normalization" identifies both (a) "Owner information duplicated across multiple properties" and (b) "No foreign key constraints enforcing referential integrity" - fully meets detection criteria |
| P04: PropertyManagementService excessive dependencies | ○ | 1.0 | Section "SOLID Violations & Structural Issues" states "PropertyManagementService has 6 direct dependencies (repositories for property, customer, appointment, contract + ElasticsearchTemplate + RedisTemplate), indicating excessive coupling" and recommends responsibility decomposition |
| P05: RESTful API design violation (verb-based URLs) | ○ | 1.0 | Section "Critical Issues → 2. Broken REST API Design" explicitly identifies "Action verbs in URLs (`/properties/create`, `/properties/delete/{id}`)" and recommends proper REST resource modeling using HTTP methods |
| P06: Error classification/recovery strategy absence | ○ | 1.0 | Section "Critical Issues → 3. No Domain Exception Design" states "no application-level error taxonomy, error codes, or retry classification exists" and explicitly mentions "No guidance for retry logic - clients don't know which errors are transient" |
| P07: Environment-specific configuration management gap | ○ | 1.0 | Section "Significant Issues → 8. Hardcoded Configuration in Production Code" identifies hardcoded credentials and states "Different environments (dev, staging, prod) cannot use different providers", explicitly addressing environment configuration management |
| P08: Test strategy specificity gap | ○ | 1.0 | Section "Significant Issues → 10. Missing Test Strategy for External Dependencies" identifies "no mock strategy for Elasticsearch, Redis, SMTP, SMS" and notes each test layer lacks clear boundaries - meets detection criteria for test strategy specificity |
| P09: Cookie-based token security risk | × | 0.0 | No mention of JWT cookie storage, CSRF risk, or security attributes (SameSite, HttpOnly) |

**Detection Subtotal: 8.0 / 9.0**

## Run 1 Bonus/Penalty Analysis

### Bonus Detections

1. **B01: CustomerManagementService responsibility ambiguity** - Not detected
2. **B02: NotificationService channel extensibility** - **DETECTED (+0.5)**: Section "Significant Issues → S4. No Strategy Pattern for Extensible Notification Channels" explicitly identifies lack of Strategy/Plugin pattern and states "Adding new notification channel requires code changes to NotificationService"
3. **B03: API versioning strategy gap** - **DETECTED (+0.5)**: Section "Significant Issues → 7. No API Versioning Strategy" identifies lack of API versioning and deprecation policy
4. **B04: Logging design specificity gap** - **DETECTED (+0.5)**: Section "Moderate Issues → 11. No Structured Logging Design" identifies lack of structured logging format and correlation IDs
5. **B05: DTO/domain model separation ambiguity** - **DETECTED (+0.5)**: Section "Changeability Risks" states "DTOs not explicitly mentioned except PropertyDTO in code samples - risk of exposing entities directly through API"
6. **B06: DI design gap (testability)** - **DETECTED (+0.5)**: Section "Significant Issues → 6. Field Injection Reduces Testability" explicitly identifies field injection harming testability

**Additional valid bonus detections:**
- Circuit breaker pattern absence for external services (Moderate Issues #12): **DETECTED (+0.5)** - within scope of error handling/resilience
- Soft delete support absence (Moderate Issues #13): **DETECTED (+0.5)** - data model evolution/audit trail
- Status field modeling issues (Moderate Issues #14): **DETECTED (+0.5)** - data model quality
- Cache coherence strategy gap (Significant Issues #9): **DETECTED (+0.5)** - within scope of state management
- Audit field absence (Minor Improvements #16): **DETECTED (+0.5)** - data model traceability

**Bonus Subtotal: +5.0** (10 valid bonus detections, capped at 5.0)

### Penalty Analysis

Potential penalties:
- Section "Moderate Issues → 12. No Circuit Breaker for External Services" discusses resilience patterns (circuit breaker, retry, timeout) which are **infrastructure-level concerns** and should be penalized
- However, this is borderline as the section focuses on application-level integration design

**Penalty: -0.5** (1 instance of infrastructure-level resilience pattern discussion)

## Run 1 Final Score

```
Detection: 8.0
Bonus: +5.0
Penalty: -0.5
Total: 12.5
```

---

## Run 2 Detection Matrix

| Problem ID | Status | Score | Evidence |
|-----------|--------|-------|----------|
| P01: PropertyManagementService SRP violation | ○ | 1.0 | Section "C1. Single Responsibility Principle Violation" explicitly states PropertyManagementService has "at least 5 distinct responsibilities, each with different change drivers" and proposes decomposition |
| P02: NotificationService external dependency coupling | ○ | 1.0 | Section "C3. No Dependency Injection Abstraction for External Services" identifies "NotificationService directly constructs SMTP connections and SMS API calls with hardcoded credentials" and recommends abstraction interfaces |
| P03: Data model redundancy and integrity risk | ○ | 1.0 | Section "M2. Embedded Attributes Prevent Normalization" identifies owner information duplication, and Section "M1. No Foreign Key Constraints Delegation Strategy" addresses referential integrity - both criteria met |
| P04: PropertyManagementService excessive dependencies | ○ | 1.0 | Section "SOLID Principles & Structural Design" notes "Field injection via @Autowired instead of constructor injection" and mentions 6 dependencies in PropertyManagementService context, linking to responsibility violation |
| P05: RESTful API design violation (verb-based URLs) | ○ | 1.0 | Section "C2. RESTful API Design Violations" explicitly lists "Action-based URLs (`/properties/create` instead of `POST /properties`)" and recommends resource-oriented design |
| P06: Error classification/recovery strategy absence | ○ | 1.0 | Section "C4. No Domain Exception Taxonomy and Error Classification" identifies lack of "application-level exception hierarchy, error codes, or classification of retryable vs non-retryable errors" - fully meets criteria |
| P07: Environment-specific configuration management gap | ○ | 1.0 | Section "M3. No Configuration Management Strategy" states "Hardcoded credentials and endpoints in code. No mention of how to manage different configurations for dev/staging/prod environments" |
| P08: Test strategy specificity gap | ○ | 1.0 | Section "M5. No Test Strategy for External Dependencies" identifies lack of testing strategy for notification delivery, Elasticsearch, Redis, and external API failures - meets criteria for test layer boundary ambiguity |
| P09: Cookie-based token security risk | × | 0.0 | No mention of JWT cookie storage or CSRF-related security attributes |

**Detection Subtotal: 8.0 / 9.0**

## Run 2 Bonus/Penalty Analysis

### Bonus Detections

1. **B01: CustomerManagementService responsibility ambiguity** - Not detected
2. **B02: NotificationService channel extensibility** - **DETECTED (+0.5)**: Section "S4. No Strategy Pattern for Extensible Notification Channels" identifies lack of extensibility and explicitly recommends Strategy pattern
3. **B03: API versioning strategy gap** - **DETECTED (+0.5)**: Section "S2. No Versioning Strategy for API and Schema Evolution" comprehensively addresses API versioning absence
4. **B04: Logging design specificity gap** - **DETECTED (+0.5)**: Section "I1. No Structured Logging Policy Defined" identifies lack of structured logging and contextual information strategy
5. **B05: DTO/domain model separation ambiguity** - **DETECTED (+0.5)**: Section "Changeability & Module Design" notes "Domain entities used directly as API response (no DTO separation mentioned for entities)"
6. **B06: DI design gap (testability)** - **DETECTED (+0.5)**: Section "S1. Field Injection Instead of Constructor Injection" explicitly addresses DI design impacting testability

**Additional valid bonus detections:**
- Cache coherence strategy gap (Significance mentioned in context): **DETECTED (+0.5)** - state management concern
- Abstraction for Elasticsearch/Redis (S3): **DETECTED (+0.5)** - infrastructure dependency abstraction
- Layer separation enforcement gap (I2): **DETECTED (+0.5)** - architectural boundary enforcement
- Status field modeling issues: **DETECTED (+0.5)** - data model quality (implied in normalization discussion)

**Bonus Subtotal: +5.0** (10 valid bonus detections, capped at 5.0)

### Penalty Analysis

No clear scope violations detected. All issues align with structural quality evaluation (SOLID, testability, API design, data model, error handling).

**Penalty: 0.0**

## Run 2 Final Score

```
Detection: 8.0
Bonus: +5.0
Penalty: 0.0
Total: 13.0
```

---

## Overall Statistics

| Metric | Run 1 | Run 2 |
|--------|-------|-------|
| Detection Score | 8.0 | 8.0 |
| Bonus | +5.0 | +5.0 |
| Penalty | -0.5 | 0.0 |
| **Total Score** | **12.5** | **13.0** |

**Mean Score**: 12.75
**Standard Deviation**: 0.25

**Stability**: High (SD ≤ 0.5) - Results are highly reliable

---

## Detection Details

### Consistent Detections (Both Runs: ○)

All 8 detected problems were consistently found in both runs:

1. **P01 (SRP violation)**: Both runs identified PropertyManagementService's multiple responsibilities with clear decomposition recommendations
2. **P02 (External dependency coupling)**: Both runs detected hardcoded SMTP/SMS credentials and recommended abstraction interfaces
3. **P03 (Data model issues)**: Both runs identified owner information duplication AND foreign key constraint absence
4. **P04 (Excessive dependencies)**: Both runs noted 6 dependencies in PropertyManagementService as a design smell
5. **P05 (REST violations)**: Both runs explicitly called out verb-based URLs and recommended proper REST resource modeling
6. **P06 (Error taxonomy gap)**: Both runs identified lack of retryable/non-retryable error classification
7. **P07 (Configuration management)**: Both runs noted hardcoded configuration and environment-specific management gaps
8. **P08 (Test strategy gaps)**: Both runs identified unclear test layer boundaries and external dependency mock strategy absence

### Consistent Non-Detections (Both Runs: ×)

**P09 (JWT cookie CSRF risk)**: Neither run mentioned JWT storage mechanism, cookie attributes (SameSite, HttpOnly), or CSRF-specific risks. The authentication section was not analyzed in depth in either run.

### Score Variance Analysis

**Primary variance source**: Run 1 included a penalty (-0.5) for discussing circuit breaker patterns (infrastructure-level concern), while Run 2 avoided this scope violation. Both runs reached the bonus cap of +5.0 with similar but slightly different bonus detection sets.

**Conclusion**: The variant demonstrates **very high stability** (SD=0.25) with consistent detection of all core structural issues across both runs. The small variance (0.5pt difference) stems from interpretation of scope boundaries rather than detection inconsistency.
