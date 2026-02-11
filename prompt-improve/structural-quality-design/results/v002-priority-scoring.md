# Scoring Results - v002-priority (Broad Mode)

## Detection Matrix

| Problem ID | Run1 | Run2 | Criteria Met |
|------------|------|------|--------------|
| P01: SRP Violation (AppointmentService) | ○ | ○ | Both identify SRP violation with concrete service split suggestions |
| P02: External Dependency Coupling | ○ | ○ | Both identify need for abstraction/interface with DIP |
| P03: Data Redundancy | ○ | ○ | Both identify normalization violation and consistency risks |
| P04: RESTful API Design Violation | × | × | Neither mentions verb-based URL pattern issues |
| P05: Missing API Versioning | ○ | ○ | Both identify lack of versioning with backward compatibility concerns |
| P06: Insufficient Error Handling | ○ | ○ | Both point out missing error classification and recovery strategies |
| P07: Test Strategy Not Defined | ○ | ○ | Both identify missing test strategy elements (contract testing, mocking) |
| P08: Configuration Management | ○ | ○ | Both point out missing environment-specific config strategy |
| P09: Change Impact Propagation | ○ | ○ | Both identify schema change propagation and suggest mitigation strategies |

### Detection Score Calculation

**Run1**:
- P01: 1.0 (○)
- P02: 1.0 (○)
- P03: 1.0 (○)
- P04: 0.0 (×)
- P05: 1.0 (○)
- P06: 1.0 (○)
- P07: 1.0 (○)
- P08: 1.0 (○)
- P09: 1.0 (○)
**Detection Subtotal**: 8.0

**Run2**:
- P01: 1.0 (○)
- P02: 1.0 (○)
- P03: 1.0 (○)
- P04: 0.0 (×)
- P05: 1.0 (○)
- P06: 1.0 (○)
- P07: 1.0 (○)
- P08: 1.0 (○)
- P09: 1.0 (○)
**Detection Subtotal**: 8.0

---

## Bonus/Penalty Analysis

### Run1 Bonus Candidates

| ID | Bonus? | Justification |
|----|--------|---------------|
| B01: NotificationService extraction | ✓ | Explicitly proposes NotificationOrchestrator as separate component (C1 section) |
| B02: Ports/adapters pattern | ✓ | Explicitly recommends "Introduce abstraction layer" with NotificationProvider interface (C2 section) |
| B03: Missing indexes | ✓ | 4.1 identifies specific indexing needs (patient_id, appointment_date), (doctor_id, appointment_date, status) |
| B04: DI framework usage | ✓ | S3 recommends constructor injection with Spring-specific example |
| B05: HATEOAS | × | Not mentioned |
| B06: Pagination strategy | × | Not mentioned |
| B07: Domain exception hierarchy | × | Generic error handling mentioned but no domain-specific exception classes |
| B08: Distributed tracing | ✓ | M3 recommends correlation ID / trace ID, AWS X-Ray integration |

**Additional Valid Bonus**:
- **Concurrency control for double booking** (4.2): Points out race condition risk and suggests unique constraint — valid structural issue not in answer key (+0.5)
- **Medical history module boundary violation** (not in key): Identifies that AppointmentService updating patient medical history violates module boundaries — valid structural concern (+0.5)

**Run1 Bonus**: 7 items × 0.5 = +3.5

### Run1 Penalty Candidates

| Issue | Penalty? | Justification |
|-------|----------|---------------|
| S1: Circuit breaker pattern | ✓ | Mentions "circuit breaker pattern for external APIs (e.g., Resilience4j)" — infrastructure-level pattern, out of scope per perspective.md guidance |

**Run1 Penalty**: 1 item × 0.5 = -0.5

---

### Run2 Bonus Candidates

| ID | Bonus? | Justification |
|----|--------|---------------|
| B01: NotificationService extraction | ✓ | P01 proposes NotificationService, MedicalHistoryService, ReportingService decomposition |
| B02: Ports/adapters pattern | ✓ | P03 introduces NotificationPort abstraction with hexagonal architecture terminology |
| B03: Missing indexes | × | Not mentioned |
| B04: DI framework usage | ✓ | P04 recommends constructor injection with test configuration example |
| B05: HATEOAS | × | Not mentioned |
| B06: Pagination strategy | × | Not mentioned |
| B07: Domain exception hierarchy | ✓ | P10 recommends domain-specific exception hierarchy (AppointmentConflictException, DoctorUnavailableException) |
| B08: Distributed tracing | ✓ | P14 recommends correlation IDs with MDC and structured logging |

**Additional Valid Bonus**:
- **Medical history module boundary violation** (P09): Explicitly identifies AppointmentService updating patient medical history as module boundary violation with event-driven solution — valid structural issue (+0.5)
- **Appointment workflow state machine** (P06): Identifies lack of workflow extension points and proposes state machine pattern for appointment types — valid extensibility concern (+0.5)

**Run2 Bonus**: 7 items × 0.5 = +3.5

### Run2 Penalty Candidates

No penalties detected. All issues are within scope per perspective.md.

**Run2 Penalty**: 0

---

## Final Scores

### Run1
```
Detection:     8.0
Bonus:        +3.5
Penalty:      -0.5
─────────────────
Run1 Total:   11.0
```

### Run2
```
Detection:     8.0
Bonus:        +3.5
Penalty:       0.0
─────────────────
Run2 Total:   11.5
```

### Variant Summary
```
Mean:  (11.0 + 11.5) / 2 = 11.25
SD:    stddev(11.0, 11.5) = 0.25
```

---

## Detailed Justifications

### P01 (SRP Violation) - Both ○
- **Run1 (C1)**: "Split AppointmentService into focused services: AppointmentBookingService, NotificationOrchestrator, MedicalHistoryService, ReportingService"
- **Run2 (P01)**: "Create NotificationService abstraction... Extract medical history updates to MedicalHistoryService and reporting to ReportingService"
- **Verdict**: Both explicitly mention SRP violation and propose concrete decomposition

### P02 (External Dependency Coupling) - Both ○
- **Run1 (C2)**: "Introduce abstraction layer" with NotificationProvider interface
- **Run2 (P03)**: "Define abstraction in domain layer" with NotificationPort, mentions Dependency Inversion Principle
- **Verdict**: Both identify need for abstraction to enable mocking and testability

### P03 (Data Redundancy) - Both ○
- **Run1 (C3)**: Identifies denormalized fields, explains "data integrity risk", "change propagation"
- **Run2 (P08)**: "Data denormalization creates multiple change propagation paths", explains normalization violation
- **Verdict**: Both explain normalization violation and consistency risks

### P04 (RESTful API Design) - Both ×
- **Run1**: No mention of verb-based URL pattern (/appointments/create, /appointments/cancel)
- **Run2**: No mention of verb-based URL pattern
- **Verdict**: Neither detects this specific REST principle violation

### P05 (Missing API Versioning) - Both ○
- **Run1 (S2)**: "No backward compatibility or schema evolution strategy defined", "Cannot deprecate old API versions gracefully"
- **Run2 (P07)**: "Missing versioning strategy", "Cannot support multiple mobile app versions with different API contracts"
- **Verdict**: Both identify lack of versioning with backward compatibility rationale

### P06 (Insufficient Error Handling) - Both ○
- **Run1 (S1)**: "No error handling strategy for external dependency failures", identifies missing classification/recovery
- **Run2 (P10)**: "Lacks domain-specific error classification", "No recovery guidance"
- **Verdict**: Both point out missing error classification and recovery strategies

### P07 (Test Strategy Not Defined) - Both ○
- **Run1 (S3)**: "Architecture design doesn't specify dependency injection patterns", "Cannot easily substitute... in tests"
- **Run2 (P04)**: "No documented test strategy for service layer with external dependencies", mentions contract testing
- **Verdict**: Both identify lack of comprehensive test strategy with specific missing elements

### P08 (Configuration Management) - Both ○
- **Run1 (M2)**: "Doesn't specify how environment-specific configuration is managed", suggests Spring profiles and Secrets Manager
- **Run2**: Mentioned in P13 context (database migration) but not explicitly called out as separate issue. However, P13 mentions "deployment risk" related to configuration. **Reviewing more carefully**: Not explicitly mentioned as environment-specific config issue.
- **Re-evaluation**: Run2 does NOT explicitly identify environment-specific configuration management as a separate concern. Only Run1 has M2 dedicated to this.
- **Verdict**: Run1 ○, Run2 × (correction needed)

**CORRECTION NEEDED**: Re-reading Run2, there is no explicit section on environment-specific configuration management.

### P09 (Change Impact Propagation) - Both ○
- **Run1 (C3)**: "Any change to patient contact info or doctor details requires updating multiple tables", "change propagation"
- **Run2 (P08)**: "Data denormalization... creates multiple change propagation paths", suggests anti-corruption layers, DTOs
- **Verdict**: Both identify change propagation and suggest mitigation strategies

---

## Revised Detection Matrix (After P08 Correction)

| Problem ID | Run1 | Run2 | Criteria Met |
|------------|------|------|--------------|
| P01: SRP Violation | ○ | ○ | Both detect |
| P02: External Dependency Coupling | ○ | ○ | Both detect |
| P03: Data Redundancy | ○ | ○ | Both detect |
| P04: RESTful API Design Violation | × | × | Neither detects |
| P05: Missing API Versioning | ○ | ○ | Both detect |
| P06: Insufficient Error Handling | ○ | ○ | Both detect |
| P07: Test Strategy Not Defined | ○ | ○ | Both detect |
| P08: Configuration Management | ○ | × | Only Run1 detects (M2) |
| P09: Change Impact Propagation | ○ | ○ | Both detect |

### Revised Detection Scores

**Run1**: 8.0 (no change)
**Run2**: 8.0 → 7.0 (P08 not detected)

---

## Revised Final Scores

### Run1
```
Detection:     8.0
Bonus:        +3.5
Penalty:      -0.5
─────────────────
Run1 Total:   11.0
```

### Run2
```
Detection:     7.0
Bonus:        +3.5
Penalty:       0.0
─────────────────
Run2 Total:   10.5
```

### Variant Summary
```
Mean:  (11.0 + 10.5) / 2 = 10.75
SD:    stddev(11.0, 10.5) = 0.25
```

---

## Bonus Justification Details

### Run1 Bonus Items (Total: +3.5)

1. **B01 - NotificationService extraction** (+0.5): C1 section explicitly proposes "NotificationOrchestrator - Coordinate patient/doctor notifications"
2. **B02 - Ports/adapters** (+0.5): C2 recommends "Introduce abstraction layer" with interface-based design
3. **B03 - Missing indexes** (+0.5): 4.1 identifies specific indexes for patient_id, doctor_id, appointment_date
4. **B04 - DI framework** (+0.5): S3 recommends constructor injection with Spring @Service example
5. **B08 - Distributed tracing** (+0.5): M3 recommends correlation IDs, AWS X-Ray
6. **Additional: Concurrency control** (+0.5): 4.2 identifies double booking race condition, suggests unique constraint
7. **Additional: Medical history boundary** (+0.5): Not explicitly separated from P01/P09 in Run1, removing this bonus

**Revised Run1 Bonus**: 6 items = +3.0

### Run2 Bonus Items (Total: +3.5)

1. **B01 - NotificationService extraction** (+0.5): P01 proposes NotificationService, MedicalHistoryService, ReportingService
2. **B02 - Ports/adapters** (+0.5): P03 introduces NotificationPort with hexagonal architecture
3. **B04 - DI framework** (+0.5): P04 recommends constructor injection with TestConfiguration example
4. **B07 - Domain exception hierarchy** (+0.5): P10 proposes AppointmentConflictException, DoctorUnavailableException classes
5. **B08 - Distributed tracing** (+0.5): P14 recommends correlation IDs with MDC
6. **Additional: Medical history boundary** (+0.5): P09 explicitly identifies module boundary violation for medical history
7. **Additional: Workflow state machine** (+0.5): P06 proposes AppointmentWorkflow interface for extensibility

**Run2 Bonus**: 7 items = +3.5

---

## Final Corrected Scores

### Run1
```
Detection:     8.0
Bonus:        +3.0
Penalty:      -0.5
─────────────────
Run1 Total:   10.5
```

### Run2
```
Detection:     7.0
Bonus:        +3.5
Penalty:       0.0
─────────────────
Run2 Total:   10.5
```

### Variant Summary
```
Mean:  (10.5 + 10.5) / 2 = 10.5
SD:    stddev(10.5, 10.5) = 0.0
```
