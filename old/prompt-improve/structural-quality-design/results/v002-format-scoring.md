# Scoring Report - v002-format

## Detection Matrix

| Problem ID | Run1 | Run2 | Description |
|-----------|------|------|-------------|
| P01 | ○ | ○ | Single Responsibility Principle Violation (AppointmentService) |
| P02 | ○ | ○ | External Dependency Directly Coupled to Service Layer |
| P03 | ○ | ○ | Data Redundancy and Normalization Violation |
| P04 | × | ○ | RESTful API Design Violation |
| P05 | ○ | × | Missing API Versioning Strategy |
| P06 | × | × | Insufficient Error Handling and Recovery Strategy |
| P07 | × | × | Test Strategy Not Defined |
| P08 | × | × | Environment-Specific Configuration Management Not Addressed |
| P09 | × | × | Change Impact Propagation Across Layers |

## Detection Details

### Run1 Analysis

**P01 (○)**: Clearly detected in "Critical Issues > 1. God Object Service"
- Explicitly identifies SRP violation
- Lists all responsibilities: booking, notifications, medical history, reporting
- Recommends decomposition into focused services

**P02 (○)**: Detected in "Critical Issues > 2. Direct External API Coupling"
- Quotes line 89: "calls external APIs (SendGrid, AWS SNS) directly"
- Identifies Dependency Inversion Principle violation
- Recommends NotificationProvider interface abstraction

**P03 (○)**: Detected in "Critical Issues > 3. Data Denormalization"
- Identifies redundant columns: patient_email, patient_phone, doctor_name, doctor_specialization
- Explains update anomalies and inconsistency risk
- References normal forms violation

**P04 (×)**: Not detected
- No mention of verb-based URL pattern (/appointments/create, /appointments/cancel)
- No reference to RESTful design principles for endpoint naming

**P05 (○)**: Detected in "Significant Issues > 4. Missing API Versioning Strategy"
- Points out lack of version prefixes
- Mentions backward compatibility concerns
- Recommends /v1/ prefix

**P06 (×)**: Partial detection only
- "Significant Issues > 5" mentions generic error handling and domain classification
- But does NOT identify missing retry logic, partial failure handling, or compensation strategies for distributed operations
- Focus is on client-facing error codes, not recovery/compensation strategies
- Judgment: × (does not meet detection criteria)

**P07 (×)**: Partial detection only
- "Minor Improvements > 10" mentions test strategy is vague
- But does NOT suggest specific missing elements: test pyramid, contract testing, mocking strategy, coverage targets
- Only defines integration test boundaries, not comprehensive strategy
- Judgment: × (does not meet detection criteria)

**P08 (×)**: Not detected
- No mention of configuration management or environment-specific settings
- No discussion of externalization strategy

**P09 (×)**: Not detected
- While "Changeability & Module Design: 2/5" mentions change amplification
- Does NOT specifically identify that schema changes propagate across all layers (database → entity → repository → service → controller → API)
- Does not suggest strategies to reduce coupling like anti-corruption layers or DTO separation
- Judgment: × (does not meet detection criteria)

### Run2 Analysis

**P01 (○)**: Detected in "Critical Issues > C1. God Object Anti-Pattern"
- Explicitly lists five distinct responsibilities
- References SRP violation
- Recommends service decomposition

**P02 (○)**: Detected in "Critical Issues > C2. Dependency Inversion Principle Violation"
- Quotes: "calls external APIs (SendGrid, AWS SNS) directly"
- Identifies DIP violation
- Provides NotificationGateway abstraction pattern

**P03 (○)**: Detected in "Critical Issues > C3. Data Denormalization Without Justification"
- Lists denormalized columns
- Explains update anomalies and data inconsistency risk
- Recommends removal or CQRS pattern

**P04 (○)**: Detected in "Minor Improvements > I1. RESTful Convention Inconsistency"
- Identifies POST /appointments/create should be POST /appointments
- References HTTP verb semantics

**P05 (×)**: Not detected
- No mention of API versioning strategy
- No reference to version prefixes or backward compatibility strategy

**P06 (×)**: Partial detection only
- "Significant Issues > S4" discusses error classification
- But does NOT identify missing retry logic, partial failure handling, or compensation strategies
- Focus is on error taxonomy (retryable vs non-retryable), not recovery mechanisms
- "Significant Issues > S3" mentions partial failure but in context of transactions, not error handling strategy
- Judgment: × (does not meet detection criteria)

**P07 (×)**: Not detected
- No discussion of comprehensive test strategy
- No mention of test pyramid, contract testing, mocking strategy, or coverage targets

**P08 (×)**: Not detected
- No mention of configuration management or environment-specific settings

**P09 (×)**: Partial detection only
- "Significant Issues > S1" mentions "Database schema changes force service layer modification"
- But does NOT provide concrete example of schema change propagating across layers
- Does not suggest mitigation strategies like anti-corruption layers or DTO separation
- Judgment: × (does not meet specific detection criteria)

## Bonus Analysis

### Run1 Bonuses

1. **B02 (Bonus +0.5)**: "Critical Issues > 2" recommends NotificationProvider interface pattern, which aligns with ports/adapters and dependency inversion principle
2. **B03 (Bonus +0.5)**: "Minor Improvements > 11" identifies missing database indexes on specific fields
3. **B04 (Bonus +0.5)**: "Significant Issues > 6" explicitly recommends constructor injection for dependency injection
4. **B06 (Bonus +0.5)**: "Moderate Issues > 10" identifies lack of pagination strategy for list endpoints
5. **B07 (Bonus +0.5)**: "Significant Issues > 5" recommends domain-specific error codes/exception hierarchy

**Total Run1 Bonuses**: 5 items × 0.5 = +2.5

### Run2 Bonuses

1. **B02 (Bonus +0.5)**: "Critical Issues > C2" recommends NotificationGateway abstraction with ports/adapters pattern
2. **B04 (Bonus +0.5)**: "Significant Issues > S2" discusses DI enforcement (prohibit instance variables except injected dependencies)
3. **B06 (Bonus +0.5)**: "Moderate Issues > M2" identifies lack of pagination for list operations
4. **B07 (Bonus +0.5)**: "Significant Issues > S4" recommends business error taxonomy with exception classes
5. **B05 (Bonus +0.5)**: "Minor Improvements > I2" suggests HATEOAS links for API discoverability

**Total Run2 Bonuses**: 5 items × 0.5 = +2.5

## Penalty Analysis

### Run1 Penalties

1. **Penalty -0.5**: "Moderate Issues > 8. No Circuit Breaker or Retry Strategy for External APIs" - This is infrastructure-level resilience pattern (circuit breaker, retry) which is EXPLICITLY out of scope per perspective.md line 22: "インフラレベルの障害回復パターン（サーキットブレーカー、リトライポリシー、フェイルオーバー、ヘルスチェック等）の指摘" is penalty target

**Total Run1 Penalties**: 1 item × -0.5 = -0.5

### Run2 Penalties

1. **Penalty -0.5**: "Significant Issues > S3. Missing Transactional Boundary Design" - While transaction management is mentioned, the perspective.md line 18 states "並行性制御、トランザクション設計 → 本観点のスコープ外". This is out of scope.

**Total Run2 Penalties**: 1 item × -0.5 = -0.5

## Score Calculation

### Run1
- Detection score: P01(1.0) + P02(1.0) + P03(1.0) + P04(0.0) + P05(1.0) + P06(0.0) + P07(0.0) + P08(0.0) + P09(0.0) = 4.0
- Bonus: +2.5
- Penalty: -0.5
- **Run1 Total: 4.0 + 2.5 - 0.5 = 6.0**

### Run2
- Detection score: P01(1.0) + P02(1.0) + P03(1.0) + P04(1.0) + P05(0.0) + P06(0.0) + P07(0.0) + P08(0.0) + P09(0.0) = 5.0
- Bonus: +2.5
- Penalty: -0.5
- **Run2 Total: 5.0 + 2.5 - 0.5 = 7.0**

### Summary Statistics
- **Mean**: (6.0 + 7.0) / 2 = 6.5
- **Standard Deviation**: sqrt(((6.0-6.5)² + (7.0-6.5)²) / 2) = sqrt((0.25 + 0.25) / 2) = sqrt(0.25) = 0.5

## Overall Assessment

**Stability**: High (SD = 0.5, at the threshold of "高安定")

**Key Observations**:
- Both runs consistently detected critical structural issues (P01-P03)
- Run2 improved RESTful API detection (P04) but missed API versioning (P05) that Run1 caught
- Neither run detected error handling strategy gaps (P06), test strategy issues (P07), configuration management (P08), or change propagation (P09)
- Both runs provided valuable bonus insights on DI patterns, pagination, and error taxonomy
- Both runs had scope violations related to infrastructure-level concerns
