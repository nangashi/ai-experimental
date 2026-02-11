# Answer Key - Round 002

## Execution Metadata
- **Perspective**: structural-quality
- **Target**: design
- **Embedded Issues**: 9 problems

## Embedded Problems

### P01: Single Responsibility Principle Violation (AppointmentService)
- **Category**: SOLID原則・構造設計
- **Severity**: 重大
- **Location**: Section 3 (Architecture Design > Core Components > AppointmentService)
- **Description**: AppointmentService is assigned multiple unrelated responsibilities: appointment booking/cancellation/rescheduling, notification sending (email/SMS), medical history updates, and report generation. This violates the Single Responsibility Principle and creates high coupling.
- **Detection Criteria**:
  - ○ (Detected): Points out that AppointmentService has too many responsibilities and should be split into separate services (e.g., AppointmentService, NotificationService, ReportService), or mentions SRP violation with concrete examples
  - △ (Partial): Mentions that the service is doing too much but does not suggest specific decomposition or reference SRP
  - × (Not Detected): No mention of responsibility separation issues

### P02: External Dependency Directly Coupled to Service Layer
- **Category**: 外部依存・テスタビリティ
- **Severity**: 重大
- **Location**: Section 3 (Architecture Design > Data Flow, step 3)
- **Description**: Service layer directly calls external APIs (SendGrid, AWS SNS) instead of going through an abstraction layer. This creates tight coupling and makes unit testing difficult without actual API calls.
- **Detection Criteria**:
  - ○ (Detected): Points out that external API dependencies should be abstracted behind interfaces/ports to enable mocking and testability, or mentions need for dependency inversion
  - △ (Partial): Mentions tight coupling to external services but does not propose abstraction/interface solution
  - × (Not Detected): No mention of external dependency coupling issues

### P03: Data Redundancy and Normalization Violation
- **Category**: データモデル設計
- **Severity**: 重大
- **Location**: Section 4 (Data Model > Appointment table)
- **Description**: The appointments table stores denormalized data (patient_email, patient_phone, doctor_name, doctor_specialization) that already exists in referenced tables. This violates normalization principles and creates data inconsistency risks when patient/doctor data is updated.
- **Detection Criteria**:
  - ○ (Detected): Identifies redundant columns in appointments table and explains normalization violation or data consistency risks
  - △ (Partial): Mentions data duplication but does not explain normalization principles or consistency risks
  - × (Not Detected): No mention of data redundancy issues

### P04: RESTful API Design Violation
- **Category**: API・データモデル品質
- **Severity**: 軽微
- **Location**: Section 5 (API Design > Create Appointment, Cancel Appointment)
- **Description**: API endpoints use verb-based paths (/appointments/create, /appointments/cancel) instead of resource-based REST conventions. Should be POST /appointments and DELETE /appointments/{id}.
- **Detection Criteria**:
  - ○ (Detected): Points out verb-based URL pattern and suggests resource-based RESTful design
  - △ (Partial): Mentions URL naming could be improved but does not reference REST principles
  - × (Not Detected): No mention of API design issues

### P05: Missing API Versioning Strategy
- **Category**: API・データモデル品質
- **Severity**: 中
- **Location**: Section 5 (API Design) and Section 2 (Technology Stack > Backend > API)
- **Description**: No API versioning strategy is defined. As the API evolves, backward compatibility cannot be maintained without version management.
- **Detection Criteria**:
  - ○ (Detected): Identifies lack of API versioning strategy and mentions backward compatibility concerns
  - △ (Partial): Suggests adding versioning but does not explain the backward compatibility rationale
  - × (Not Detected): No mention of API versioning

### P06: Insufficient Error Handling and Recovery Strategy
- **Category**: エラーハンドリング・オブザーバビリティ
- **Severity**: 中
- **Location**: Section 6 (Implementation Guidelines > Error Handling)
- **Description**: Error handling only covers exception-to-HTTP-status mapping. No guidance on business-level error classification (transient vs permanent), retry logic, partial failure handling, or compensation strategies for distributed operations.
- **Detection Criteria**:
  - ○ (Detected): Points out missing error classification, recovery strategies, or compensation logic for distributed transactions
  - △ (Partial): Mentions error handling is basic but does not specify what is missing
  - × (Not Detected): No mention of error handling strategy gaps

### P07: Test Strategy Not Defined
- **Category**: テスト設計・テスタビリティ
- **Severity**: 中
- **Location**: Section 6 (Implementation Guidelines > Testing)
- **Description**: Testing section only mentions "unit tests for service layer" and "integration tests for critical flows" without defining clear test strategy (test pyramid, coverage targets, contract testing for external APIs, mocking strategy, etc.).
- **Detection Criteria**:
  - ○ (Detected): Identifies lack of comprehensive test strategy and suggests specific missing elements (test pyramid, contract testing, mocking strategy, coverage targets)
  - △ (Partial): Mentions testing guidance is insufficient but does not specify concrete missing elements
  - × (Not Detected): No mention of test strategy issues

### P08: Environment-Specific Configuration Management Not Addressed
- **Category**: 拡張性・運用設計
- **Severity**: 軽微
- **Location**: Section 2 (Technology Stack) and Section 6 (Implementation Guidelines > Deployment)
- **Description**: No mention of how environment-specific configurations (dev/staging/prod) will be managed. Hard-coded values or missing externalization strategy can lead to deployment issues.
- **Detection Criteria**:
  - ○ (Detected): Points out missing configuration management strategy and suggests externalization approach (e.g., environment variables, configuration servers)
  - △ (Partial): Mentions configuration management but does not provide concrete approach
  - × (Not Detected): No mention of configuration management

### P09: Change Impact Propagation Across Layers
- **Category**: 変更容易性・モジュール設計
- **Severity**: 中
- **Location**: Section 3 (Architecture Design > Data Flow) and Section 5 (API Design)
- **Description**: Adding a new field to the appointment (e.g., "priority" level) would require changes across multiple layers: database schema, entity class, repository, service, controller, and API contract. No strategy for minimizing change propagation.
- **Detection Criteria**:
  - ○ (Detected): Identifies that schema changes propagate across all layers and suggests strategies to reduce coupling (e.g., anti-corruption layers, DTOs separated from entities)
  - △ (Partial): Mentions tight coupling between layers but does not provide mitigation strategies
  - × (Not Detected): No mention of change propagation issues

## Bonus Problem Candidates

| ID | Category | Description | Bonus Condition |
|----|----------|-------------|-----------------|
| B01 | SOLID | Suggests extracting NotificationService from AppointmentService as a separate component | Explicitly proposes creating NotificationService or similar abstraction |
| B02 | Dependency Inversion | Recommends introducing ports/adapters pattern or hexagonal architecture for external integrations | Mentions ports/adapters, hexagonal architecture, or dependency inversion principle |
| B03 | Data Model | Points out missing indexes on frequently queried fields (e.g., appointment_date, status) | Identifies specific indexing needs for query performance |
| B04 | テスタビリティ | Notes that DI framework usage is not explicitly mentioned and recommends constructor injection | Recommends constructor injection or mentions DI configuration |
| B05 | API Design | Suggests using hypermedia links (HATEOAS) for better API discoverability | Mentions HATEOAS or hypermedia |
| B06 | 拡張性 | Identifies lack of pagination strategy for list endpoints | Points out need for pagination on GET /appointments/patient/{patientId} |
| B07 | エラー設計 | Recommends domain-specific exception hierarchy instead of generic exceptions | Suggests creating domain exception classes |
| B08 | 可観測性 | Points out missing distributed tracing strategy (e.g., correlation IDs across microservices) | Mentions correlation IDs, trace IDs, or distributed tracing |
