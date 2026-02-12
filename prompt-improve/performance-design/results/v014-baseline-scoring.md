# Scoring Report - baseline (v014)

## Detection Matrix

| Problem ID | Run1 | Run2 | Notes |
|-----------|------|------|-------|
| P01 | × | × | Neither run mentions missing throughput SLA or percentile-based response time targets (p95, p99) |
| P02 | ○ | ○ | Both runs identify N+1 query pattern in financial summary endpoint and recommend JOIN/aggregation |
| P03 | ○ | ○ | Both runs point out Redis is listed but no cache strategy defined, recommend cache-aside pattern |
| P04 | ○ | ○ | Both runs identify unbounded query in payment history and connect to 7-year retention policy |
| P05 | ○ | ○ | Both runs identify synchronous external API calls (Checkr background check, Stripe payment) should be async |
| P06 | ○ | ○ | Both runs identify missing database indexes and specify required columns based on query patterns |
| P07 | ○ | ○ | Both runs identify time-series data growth problem and recommend partitioning/archival strategy |
| P08 | △ | × | Run1 mentions S3 upload optimization and presigned URLs but does not specifically identify multi-file upload scenario or batch processing. Run2 has no mention. |
| P09 | △ | △ | Run1 mentions optimistic locking and idempotency for payment operations but does not specifically identify duplicate payment risk during concurrent requests. Run2 mentions similar concurrency control but also lacks explicit duplicate payment risk identification. |

## Bonus Detection

### Run1 Bonus Issues
1. **Connection pooling configuration for external APIs (S4)** - +0.5 (matches B01 intent for connection management)
2. **Read replica strategy for reporting queries (M2)** - +0.5 (matches B08)
3. **Performance monitoring metrics (M4)** - +0.5 (matches B06)
4. **API rate limiting may be insufficient (M4 mentions 100 req/min)** - +0.5 (matches B04)
5. **Static asset delivery optimization with CloudFront (I-5 mentions S3 Transfer Acceleration)** - +0.5 (matches B03 intent for CloudFront optimization)

**Run1 Total Bonus: +2.5 (5 valid bonus issues, capped at 5 issues × 0.5)**

### Run2 Bonus Issues
1. **Connection pooling configuration for external APIs (S4)** - +0.5 (matches B01 intent)
2. **Performance monitoring metrics (M4)** - +0.5 (matches B06)

**Run2 Total Bonus: +1.0 (2 valid bonus issues)**

## Penalty Assessment

### Run1 Penalties
- **Query timeout configuration (C-4, M2)**: This is related to reliability/resilience rather than pure performance. However, query timeouts prevent connection pool exhaustion which is a performance concern, so this is borderline. Given the perspective's scope includes "connection pooling, resource release" and the impact is on throughput/availability, this is considered within scope. **No penalty.**
- **Stateful architecture limiting horizontal scaling (S-4)**: This addresses scalability design (session management, stateless design) which is explicitly in scope. **No penalty.**
- **All other issues are performance-related. No penalties.**

**Run1 Total Penalty: 0**

### Run2 Penalties
- **All issues are performance-related. No penalties.**

**Run2 Total Penalty: 0**

## Score Calculation

### Run1
- P01: 0.0 (×)
- P02: 1.0 (○)
- P03: 1.0 (○)
- P04: 1.0 (○)
- P05: 1.0 (○)
- P06: 1.0 (○)
- P07: 1.0 (○)
- P08: 0.5 (△)
- P09: 0.5 (△)

**Detection Score: 7.0**
**Bonus: +2.5**
**Penalty: -0.0**
**Run1 Total: 9.5**

### Run2
- P01: 0.0 (×)
- P02: 1.0 (○)
- P03: 1.0 (○)
- P04: 1.0 (○)
- P05: 1.0 (○)
- P06: 1.0 (○)
- P07: 1.0 (○)
- P08: 0.0 (×)
- P09: 0.5 (△)

**Detection Score: 6.5**
**Bonus: +1.0**
**Penalty: -0.0**
**Run2 Total: 7.5**

## Summary Statistics

- **Mean Score**: (9.5 + 7.5) / 2 = **8.5**
- **Standard Deviation**: sqrt(((9.5-8.5)^2 + (7.5-8.5)^2) / 2) = sqrt((1.0 + 1.0) / 2) = sqrt(1.0) = **1.0**
- **Stability**: Medium (0.5 < SD ≤ 1.0)

## Detailed Notes

### P01 Analysis
Neither run explicitly mentions the absence of **throughput SLA** (requests per second, transactions per minute) or **percentile-based response time targets** (p50, p95, p99). Both runs mention performance targets are incomplete or need enhancement, but they do not specifically identify the missing throughput metrics or percentile-based SLA definition as required by the detection criteria.

### P08 Analysis
Run1 mentions S3 presigned URLs and file upload optimization, which relates to the issue but does not specifically identify the **multi-file upload scenario** (lease workflow requiring multiple documents simultaneously) or recommend **batch upload processing/concurrent S3 uploads** as specified in detection criteria. This is a partial detection (△) because it addresses file upload efficiency without identifying the batch processing need.

Run2 has no mention of file upload optimization, so it's undetected (×).

### P09 Analysis
Both runs mention concurrency control, optimistic locking, and idempotency for payment operations. However, neither run explicitly identifies the **duplicate payment processing risk** during concurrent requests (double-click, network retry) or the specific scenario of peak payment periods causing race conditions. The detection criteria require identifying duplicate payment risk and recommending idempotency key/uniqueness constraint implementation. Both runs address concurrency control generally but miss the specific duplicate payment scenario, qualifying as partial detection (△).

### Bonus Analysis
- Run1 detected 5 valid bonus issues (connection pooling for external APIs, read replica strategy, performance monitoring, rate limiting concern, S3 Transfer Acceleration)
- Run2 detected 2 valid bonus issues (connection pooling for external APIs, performance monitoring)
- All bonus issues are valid observations within performance scope and not duplicates of embedded issues
