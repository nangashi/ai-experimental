# Scoring Report: v007-baseline

## Scoring Metadata
- Prompt: v007-baseline
- Perspective: consistency-design
- Scoring Date: 2026-02-11
- Total Embedded Problems: 10
- Total Bonus Opportunities: 7

---

## Run 1 Scoring

### Detection Matrix

| Problem ID | Problem Description | Detection | Score | Evidence |
|------------|---------------------|-----------|-------|----------|
| P01 | Mixed Table Naming Conventions (Singular vs Plural) | × | 0.0 | No mention of singular vs plural table naming patterns. Document discusses column naming but not table naming convention issues. |
| P02 | Inconsistent Column Naming Conventions (camelCase vs snake_case) | ○ | 1.0 | **C1** identifies mixing of camelCase and snake_case across multiple tables with specific examples: "Patient: camelCase (firstName, lastName) mixed with snake_case (created_at)", "Provider: snake_case (first_name) mixed with camelCase (createdAt)", "Appointment: camelCase (appointmentId) mixed with snake_case (scheduled_time, duration_minutes)". Provides examples from all entities. |
| P03 | Inconsistent Foreign Key Naming Convention | ○ | 1.0 | **C1** specifically identifies FK naming inconsistency: "Foreign key naming lacks consistency: patientId (camelCase in Appointment), doctor_id (snake_case in Appointment), provider_ref (snake_case with different suffix in AvailabilitySlot)". Also notes the pattern discrepancy in **C2**. |
| P04 | Missing Documentation of Data Access Pattern | △ | 0.5 | **C2** mentions "Whether services can directly access repositories of other aggregates" and "Unclear whether controllers or services are responsible for request/response transformation" but doesn't specifically identify missing documentation of repository patterns, query method naming, or consistent data access patterns across services. |
| P05 | Inconsistent Timestamp Column Naming | ○ | 1.0 | **C1** specifically identifies timestamp naming inconsistency with examples from all tables: "Timestamp fields use three different naming patterns: Patient: created_at, updated_at; Provider: createdAt, updatedAt (camelCase); Appointment: created_timestamp, last_modified". |
| P06 | API Endpoint Inconsistency (Action-Based vs RESTful) | ○ | 1.0 | **S1** identifies the mixing of REST-style and action-based approaches: "Patient: REST-style (POST /patients, PUT /patients/{id}); Appointments: Mixed style (POST /api/appointments/create, PUT /api/appointments/{id}/update)" and notes "Some endpoints redundantly include action in path (/create, /update, /cancel)". |
| P07 | Missing Error Handling Pattern Documentation | ○ | 1.0 | **C3** specifically points out error handling pattern documentation issues: notes try-catch approach "Conflicts with Modern Spring Practices" that typically use @ControllerAdvice, and identifies "Missing Global Handler Reference: No mention of whether a global exception handler exists in the current codebase". |
| P08 | Mixed API Response Structure Documentation | △ | 0.5 | **I1 (API Response Format Consistency)** mentions "it's unclear whether: All endpoints follow this format (including Patient and Provider endpoints)" but doesn't frame it as a critical documentation gap preventing consistency verification. |
| P09 | Inconsistent HTTP Client Library Choice | × | 0.0 | No mention of RestTemplate vs WebClient or HTTP client library choice. |
| P10 | Missing Directory Structure and File Placement Guidelines | ○ | 1.0 | **M4** identifies missing package structure documentation: "Package Structure Not Documented: No specification of Java package naming conventions, Unclear whether organization is by layer or by domain, No reference to existing package structure patterns". |

**Detection Subtotal: 7.0**

### Bonus Analysis

| Bonus ID | Description | Awarded | Score | Evidence |
|----------|-------------|---------|-------|----------|
| B01 | Primary key naming inconsistency - Patient.id vs Provider.providerId vs Appointment.appointmentId vs AvailabilitySlot.slot_id | Yes | +0.5 | **C1** specifically identifies: "Primary key fields: id (Patient) vs providerId (Provider) vs appointmentId (Appointment) vs slot_id (AvailabilitySlot)" - all 4 different patterns noted. |
| B02 | JWT token storage inconsistency - cookies vs Authorization header | Yes | +0.5 | **S2** identifies "Token Storage Contradiction: Section 5: JWT tokens must be included in the Authorization header; Section 7: JWT tokens stored in httpOnly cookies; These are mutually exclusive approaches". |
| B03 | Path prefix inconsistency - /patients vs /api/appointments | Yes | +0.5 | **S1** notes "Path prefix inconsistency: Patient endpoints: /patients/{id} (no /api prefix); Appointment endpoints: /api/appointments/{id} (includes /api prefix)". |
| B04 | Boolean column naming - is_available vs Java boolean naming | × | 0.0 | No mention of boolean column naming conventions. |
| B05 | Cascade deletion and orphan handling strategy not documented | × | 0.0 | No mention of cascade deletion or orphan removal strategy. |
| B06 | Transaction management pattern not documented | Yes | +0.5 | **M1** identifies "Missing Transaction Boundary Documentation: unclear whether transactions are service-level or repository-level, No mention of transaction propagation rules", and notes "No reference to existing transaction management patterns in the codebase". |
| B07 | Enum value naming inconsistency | × | 0.0 | No mention of enum value naming conventions. |

**Bonus Subtotal: +2.0**

### Penalty Analysis

No penalties identified. All issues raised are within the consistency evaluation scope (existing pattern alignment, missing documentation preventing consistency verification).

**Penalty Subtotal: 0**

### Run 1 Total Score

```
Run1 Score = 7.0 (detection) + 2.0 (bonus) - 0 (penalty) = 9.0
```

---

## Run 2 Scoring

### Detection Matrix

| Problem ID | Problem Description | Detection | Score | Evidence |
|------------|---------------------|-----------|-------|----------|
| P01 | Mixed Table Naming Conventions (Singular vs Plural) | × | 0.0 | No mention of singular vs plural table naming strategy. Document discusses column naming but not table naming convention issues. |
| P02 | Inconsistent Column Naming Conventions (camelCase vs snake_case) | ○ | 1.0 | **C1** identifies column naming across multiple tables: "Patient entity: Uses camelCase (firstName, lastName, phoneNumber, dateOfBirth) mixed with snake_case (created_at, updated_at)", "Provider entity: Uses snake_case (first_name, last_name) mixed with camelCase (createdAt, updatedAt)", "Appointment entity: Uses camelCase (appointmentId, patientId) mixed with snake_case (doctor_id, scheduled_time)". Examples from 3+ tables provided. |
| P03 | Inconsistent Foreign Key Naming Convention | ○ | 1.0 | **C2** specifically identifies FK naming inconsistency: "Foreign key references use inconsistent naming patterns: patientId references Patient.id (using camelCase, targets simple 'id'), doctor_id references Provider.providerId (using snake_case, targets qualified 'providerId'), provider_ref references Provider.providerId (using descriptive suffix '_ref')". |
| P04 | Missing Documentation of Data Access Pattern | × | 0.0 | **M1** mentions transaction management but doesn't specifically identify missing documentation of repository patterns, query method naming conventions, or data access pattern documentation. |
| P05 | Inconsistent Timestamp Column Naming | ○ | 1.0 | **C1** identifies with specific examples: "Timestamp fields: created_at (Patient) vs createdAt (Provider) vs created_timestamp (Appointment)" and later "Timestamp fields use three different naming patterns: Patient: created_at, updated_at; Provider: createdAt, updatedAt (camelCase); Appointment: created_timestamp, last_modified". |
| P06 | API Endpoint Inconsistency (Action-Based vs RESTful) | ○ | 1.0 | **S1** identifies the mixing: "Patient endpoints (RESTful style): GET /patients/{id}, POST /patients, etc.", "Appointment endpoints (mixed RESTful and RPC style): POST /api/appointments/create, PUT /api/appointments/{id}/update", notes "Action naming: RESTful implicit actions vs explicit actions (/create)" and "Sub-resource style: Direct HTTP verbs vs action suffixes (/update, /cancel)". |
| P07 | Missing Error Handling Pattern Documentation | ○ | 1.0 | **C3** identifies error handling pattern documentation gap: "Section 6 states: Each controller method includes try-catch blocks", notes "Conflicts with Modern Spring Practices: Spring Boot 3.1 typically uses @ControllerAdvice", and identifies "Missing Global Handler Reference: No mention of whether a global exception handler exists". |
| P08 | Mixed API Response Structure Documentation | △ | 0.5 | **I1 (API Response Format Consistency)** mentions "it's unclear whether: All endpoints follow this format (including Patient and Provider endpoints)" but frames it as minor improvement rather than major documentation gap. |
| P09 | Inconsistent HTTP Client Library Choice | × | 0.0 | No mention of RestTemplate vs WebClient or HTTP client library choice. |
| P10 | Missing Directory Structure and File Placement Guidelines | ○ | 1.0 | **M4** specifically identifies: "Package Structure Not Documented: No specification of Java package naming conventions, Unclear whether organization is by layer or by domain, No reference to existing package structure patterns", "File Naming Conventions Missing". |

**Detection Subtotal: 6.5**

### Bonus Analysis

| Bonus ID | Description | Awarded | Score | Evidence |
|----------|-------------|---------|-------|----------|
| B01 | Primary key naming inconsistency - Patient.id vs Provider.providerId vs Appointment.appointmentId vs AvailabilitySlot.slot_id | Yes | +0.5 | **C1** identifies: "Primary key fields: id (Patient) vs providerId (Provider) vs appointmentId (Appointment) vs slot_id (AvailabilitySlot)" - all 4 patterns noted. |
| B02 | JWT token storage inconsistency - cookies vs Authorization header | Yes | +0.5 | **M3** identifies "Authentication Token Storage Inconsistency: Section 5 states: JWT tokens will be issued upon successful login and must be included in the Authorization header; Section 7 states: JWT tokens stored in httpOnly cookies; Issue: These are two different token delivery mechanisms". |
| B03 | Path prefix inconsistency - /patients vs /api/appointments | Yes | +0.5 | **S1** notes "Base path: /patients vs /api/appointments (inconsistent /api prefix)" and "Inconsistencies: Base path: /patients vs /api/appointments/create (inconsistent /api prefix)". |
| B04 | Boolean column naming - is_available vs Java boolean naming | × | 0.0 | No mention of boolean column naming conventions. |
| B05 | Cascade deletion and orphan handling strategy not documented | × | 0.0 | No mention of cascade deletion or orphan removal strategy. |
| B06 | Transaction management pattern not documented | Yes | +0.5 | **M1** identifies "Missing Transaction Boundary Documentation: Section 3 describes data flow but doesn't specify where transactions begin/end, Unclear whether transactions are service-level or repository-level, No mention of transaction propagation rules". |
| B07 | Enum value naming inconsistency | × | 0.0 | No mention of enum value naming conventions. |

**Bonus Subtotal: +2.0**

### Penalty Analysis

No penalties identified. All issues raised are within the consistency evaluation scope (existing pattern alignment, internal inconsistencies, missing documentation preventing consistency verification).

**Penalty Subtotal: 0**

### Run 2 Total Score

```
Run2 Score = 6.5 (detection) + 2.0 (bonus) - 0 (penalty) = 8.5
```

---

## Summary Statistics

| Metric | Run 1 | Run 2 | Mean | SD |
|--------|-------|-------|------|-----|
| **Detection Score** | 7.0 | 6.5 | 6.75 | 0.25 |
| **Bonus Points** | +2.0 | +2.0 | +2.0 | 0.0 |
| **Penalty Points** | 0 | 0 | 0 | 0.0 |
| **Total Score** | 9.0 | 8.5 | 8.75 | 0.25 |

**Standard Deviation Calculation:**
```
SD = sqrt(((9.0 - 8.75)^2 + (8.5 - 8.75)^2) / 2)
   = sqrt((0.25^2 + 0.25^2) / 2)
   = sqrt((0.0625 + 0.0625) / 2)
   = sqrt(0.0625)
   = 0.25
```

---

## Stability Assessment

**SD = 0.25** → **High Stability** (SD ≤ 0.5)

The results are highly stable and reliable across both runs.

---

## Detection Pattern Analysis

### Consistently Detected (Both Runs: ○)
- P02: Inconsistent Column Naming (camelCase vs snake_case)
- P03: Inconsistent Foreign Key Naming
- P05: Inconsistent Timestamp Column Naming
- P06: API Endpoint Inconsistency (Action-Based vs RESTful)
- P07: Missing Error Handling Pattern Documentation
- P10: Missing Directory Structure Guidelines

### Partial Detection Variance
- P04: Missing Data Access Pattern Documentation
  - Run 1: △ (0.5) - mentioned architectural boundaries but not specific repository patterns
  - Run 2: × (0.0) - focused on transaction management instead
- P08: Mixed API Response Structure Documentation
  - Both runs: △ (0.5) - identified but framed as minor rather than major gap

### Consistently Missed (Both Runs: ×)
- P01: Mixed Table Naming Conventions (Singular vs Plural)
- P09: Inconsistent HTTP Client Library Choice (RestTemplate)

### Bonus Detection Consistency
- B01, B02, B03, B06: Consistently detected in both runs
- B04, B05, B07: Consistently missed in both runs

---

## Key Observations

1. **Strong Core Detection**: The prompt reliably detects naming convention inconsistencies (columns, foreign keys, timestamps, APIs) and missing pattern documentation (error handling, directory structure).

2. **Architectural Documentation Gap**: Both runs excel at identifying missing architectural and implementation pattern documentation, which aligns well with the consistency perspective's focus on "missing information that prevents consistency verification".

3. **Systematic Blind Spot - Table Names**: Neither run detected the singular vs plural table naming issue (P01), suggesting the prompt may be more focused on column-level and code-level patterns than schema-level conventions.

4. **Technology Choice Blind Spot**: Neither run detected the RestTemplate vs WebClient inconsistency (P09), possibly because the prompt doesn't emphasize library version alignment with Spring Boot 3.x conventions.

5. **Excellent Bonus Detection**: 4 out of 7 bonus problems detected consistently, showing good depth of analysis beyond the embedded problems.

6. **High Stability**: SD of 0.25 indicates the prompt produces very consistent results across runs, with only minor variance in P04 detection.

---

## Recommendations for Prompt Improvement

### Address Systematic Blind Spots

1. **Table Naming Conventions**:
   - Add explicit guidance to check table naming patterns (singular vs plural)
   - Include table-level naming in the naming conventions checklist

2. **Technology Stack Alignment**:
   - Add guidance to verify library choices align with framework version conventions
   - Include HTTP client library, ORM version, and other key dependency choices in evaluation scope

### Strengthen Partial Detections

3. **Data Access Pattern Documentation**:
   - Add explicit checklist item for repository pattern documentation
   - Include query method naming, transaction boundaries, and data access consistency

4. **API Response Format Documentation**:
   - Elevate API response format consistency to higher severity
   - Frame as "missing documentation preventing consistency verification" rather than "minor improvement"

### Maintain Strengths

5. **Keep Focus on Missing Documentation**: The current emphasis on "missing information that prevents consistency verification" is highly effective and aligns well with the consistency perspective.

6. **Maintain Architectural Analysis Depth**: The prompt's ability to identify architectural pattern documentation gaps is excellent and should be preserved.
