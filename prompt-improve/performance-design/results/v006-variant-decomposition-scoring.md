# Scoring Report: v006-variant-decomposition

**Variant**: variant-decomposition
**Perspective**: performance
**Target**: design
**Scoring Date**: 2026-02-11

---

## Detection Matrix

| Problem ID | Problem Description | Run1 | Run2 | Criteria |
|-----------|---------------------|------|------|----------|
| P01 | Missing Performance SLA Definition | △ (0.5) | △ (0.5) | Both mention performance requirements/SLAs but don't specifically identify API response time, ingestion latency, or query performance as missing categories |
| P02 | N+1 Query Problem in Tenant Buildings List | ○ (1.0) | ○ (1.0) | Perfect detection: Both explicitly identify N+1 in sensor_count aggregation with JOIN solution |
| P03 | Missing Cache Strategy for Building Metadata | ○ (1.0) | ○ (1.0) | Perfect detection: Both identify lack of caching for building/sensor metadata with read-heavy pattern impact |
| P04 | Synchronous Analytics Report Generation Blocking | ○ (1.0) | ○ (1.0) | Perfect detection: Both identify blocking operation causing thread exhaustion with async job pattern recommendation |
| P05 | Unbounded Time Range Query Risk | △ (0.5) | × (0.0) | Run1 mentions large result sets and pagination but doesn't identify 90-day unbounded range risk specifically; Run2 no mention |
| P06 | Missing Index on Time-Series Query Patterns | ○ (1.0) | ○ (1.0) | Perfect detection: Both identify missing building_id + timestamp index with join inefficiency explanation |
| P07 | Database Connection Pool Exhaustion Risk | ○ (1.0) | ○ (1.0) | Perfect detection: Both identify connection pool exhaustion from multiple services/long transactions with pooling solutions |
| P08 | Alert Processing Polling Overhead | ○ (1.0) | ○ (1.0) | Perfect detection: Both identify polling inefficiency at scale with event-driven recommendation |
| P09 | Missing Time-Series Data Lifecycle Management | × (0.0) | × (0.0) | Both mention compression but don't identify lack of automated retention/archival mechanism |
| P10 | Concurrent Write Contention on Daily Summaries | × (0.0) | × (0.0) | Not detected in either run |

---

## Bonus Findings

### Run1 (6 bonuses, 5 counted due to cap)

| ID | Finding | Location | Justification |
|----|---------|----------|---------------|
| B1 | Aggregation hourly schedule lag during high load | M1, Section 6 | Valid: Processing 417K readings/hour may exceed 60-minute window during peak load, causing aggregation backlog |
| B2 | PDF report generation in-process memory risk | M2, Section 6 | Valid: In-memory PDF rendering (100-500 MB) creates OOM risk with concurrent reports |
| B3 | Daily summary cost calculation API latency | M4, Section 4 | Valid: External API call for cost_estimate introduces latency and failure modes not addressed |
| B4 | No database query timeout configuration | M5, Section 6 | Valid: Long-running queries can hold connections indefinitely without timeout protection |
| B5 | Read replicas for analytics queries | I1, Section 2 | Valid: Heavy analytics queries on primary create contention with real-time writes |
| B6 | Structured logging for query performance | I3, Section 6 | Valid: Adding query_duration_ms fields enables automated performance analysis (capped, not counted) |

### Run2 (3 bonuses)

| ID | Finding | Location | Justification |
|----|---------|----------|---------------|
| B1 | Inefficient batch ingestion response | M1, Section 5 | Valid: Generic 202 response without per-reading validation causes retry amplification |
| B2 | No read replica strategy | M3, Section 2 | Valid: Single database creates read/write contention; read replicas enable workload isolation |
| B3 | Aggregation job frequency optimization | I1, Section 6 | Valid: Hourly aggregation may be too coarse for real-time dashboards; 5-minute tiering suggested |

---

## Penalties

### Run1
None - all findings are within performance scope

### Run2
None - all findings are within performance scope

---

## Score Breakdown

### Run1
- **Detection Score**: 7.0
  - P01: 0.5 (partial)
  - P02: 1.0 (full)
  - P03: 1.0 (full)
  - P04: 1.0 (full)
  - P05: 0.5 (partial)
  - P06: 1.0 (full)
  - P07: 1.0 (full)
  - P08: 1.0 (full)
  - P09: 0.0 (miss)
  - P10: 0.0 (miss)
- **Bonus**: +2.5 (6 bonuses found, capped at 5 = 2.5 points)
- **Penalty**: 0.0
- **Total**: 7.0 + 2.5 - 0.0 = **9.5**

### Run2
- **Detection Score**: 7.5
  - P01: 0.5 (partial)
  - P02: 1.0 (full)
  - P03: 1.0 (full)
  - P04: 1.0 (full)
  - P05: 0.0 (miss)
  - P06: 1.0 (full)
  - P07: 1.0 (full)
  - P08: 1.0 (full)
  - P09: 0.0 (miss)
  - P10: 0.0 (miss)
- **Bonus**: +1.5 (3 bonuses)
- **Penalty**: 0.0
- **Total**: 7.5 + 1.5 - 0.0 = **9.0**

---

## Summary Statistics

- **Mean Score**: 9.25
- **Standard Deviation**: 0.25
- **Stability**: High (SD ≤ 0.5)
- **Detection Rate**: 75% (P02, P03, P04, P06, P07, P08 fully detected; P01, P05 partially detected; P09, P10 missed)

---

## Key Observations

### Strengths
1. **Consistent critical issue detection**: Both runs perfectly detected all 5 critical issues (C1-C5 in runs map to P02, P03, P04, P06, P07, P08)
2. **High stability**: SD of 0.25 indicates extremely consistent performance across runs
3. **Rich bonus findings**: 6 valid bonus findings in Run1, 3 in Run2, demonstrating deep analysis beyond answer key
4. **No false positives**: Zero penalties in both runs, all findings stay within performance scope

### Weaknesses
1. **P09 (Data Lifecycle) missed**: Both runs mention compression but fail to identify the core issue of missing automated retention policies
2. **P10 (Concurrent Write Contention) missed**: Neither run detected concurrent write risk on daily_summaries aggregation
3. **P05 inconsistency**: Run1 partially detected unbounded query range (0.5), Run2 completely missed it (0.0), contributing to score variance
4. **P01 partial detection**: Both runs only partially detected missing SLA definitions (△ instead of ○)

### Improvement Opportunities
1. Add explicit focus on "data lifecycle automation" patterns (retention policies, scheduled purges)
2. Strengthen concurrency control analysis for aggregation patterns
3. Improve detection of unbounded API parameter risks (max limits, pagination requirements)
4. Enhance SLA definition coverage to explicitly check for API latency, ingestion throughput, and query time targets
