# Scoring Results: baseline (v004)

## Summary Statistics
- **Prompt**: baseline
- **Mean Score**: 12.5
- **Standard Deviation**: 0.5
- **Run1 Score**: 13.0 (detection: 9.0 + bonus: 4 - penalty: 0)
- **Run2 Score**: 12.0 (detection: 9.0 + bonus: 3 - penalty: 0)

---

## Run 1 Scoring (v004-baseline-run1.md)

### Detection Matrix

| Problem ID | Category | Detection | Score | Evidence |
|------------|----------|-----------|-------|----------|
| P01 | SOLID/Structure | ○ | 1.0 | C-1 identifies multiple responsibilities (payment, email, QR code, event notifications) in TicketSalesEngine and recommends decomposition into separate services |
| P02 | SOLID/Dependency | ○ | 1.0 | C-2 identifies direct Stripe API calls and direct EventManager calls without abstraction, recommends IEventRepository and IPaymentGateway interfaces |
| P03 | Data Model | ○ | 1.0 | C-4 explicitly identifies redundant fields: events.organizer_name/email and tickets.event_title/date/venue_name, proposes normalization or event sourcing |
| P04 | Error Handling/Recovery | ○ | 1.0 | S-4 identifies missing transaction boundaries for payment→ticket→inventory flow, recommends Saga pattern with compensating transactions |
| P05 | State Management | ○ | 1.0 | S-3 explicitly identifies localStorage vulnerability for JWT tokens, recommends httpOnly cookies |
| P06 | Test Design/DI | ○ | 1.0 | C-2 addresses lack of DI and direct dependencies; M-1 addresses undefined unit test strategy |
| P07 | API Quality | ○ | 1.0 | S-2 identifies verb-based URLs (/events/create, /events/{id}/update) and provides correct REST alternatives |
| P08 | Operational Design | ○ | 1.0 | M-2 identifies manual .env switching risk, recommends AWS Systems Manager Parameter Store |
| P09 | Module Coupling | ○ | 1.0 | C-2 identifies direct EventManager calls from TicketSalesEngine, recommends interface-based abstractions |

**Total Detection Score: 9.0 / 9.0**

### Bonus Points

| Bonus ID | Category | Awarded | Evidence |
|----------|----------|---------|----------|
| B01 | SOLID (Auth/Authz separation) | × | Not mentioned |
| B02 | Error classification strategy | ○ | S-6 provides detailed error taxonomy (client errors, retriable, permanent failures) |
| B03 | API versioning | ○ | S-1 explicitly identifies lack of versioning and provides implementation strategy |
| B04 | Concurrency control | ○ | M-6 identifies race condition for concurrent purchases of last seat, proposes optimistic/pessimistic locking |
| B05 | Error case testing | × | M-1 mentions test strategy but lacks specific error case testing focus |
| Additional 1 | Resilience patterns | ○ | M-3 identifies missing circuit breaker and retry patterns for Stripe API |
| Additional 2 | Distributed tracing | ○ | M-4 identifies missing correlation IDs for request tracing |
| Additional 3 | Idempotency | ○ | M-5 identifies missing idempotency for purchase endpoint, proposes idempotency key mechanism |
| Additional 4 | Domain layer design | ○ | C-3 identifies anemic data model and lack of domain layer |
| Additional 5 | Cache invalidation | ○ | S-5 identifies missing cache invalidation strategy for Redis |

**Bonus Count: 8 items detected**
**Bonus Score: +4.0 (capped at 5.0)**

### Penalty Analysis

No penalties detected. All issues fall within the structural-quality scope:
- Infrastructure resilience patterns (M-3) are framed as application-level error handling, which is in-scope
- No security-only issues (S-3 JWT storage has structural design implications)
- No performance-only issues

**Penalty Score: 0**

### Run 1 Final Score
**13.0** = 9.0 (detection) + 4.0 (bonus) - 0 (penalty)

---

## Run 2 Scoring (v004-baseline-run2.md)

### Detection Matrix

| Problem ID | Category | Detection | Score | Evidence |
|------------|----------|-----------|-------|----------|
| P01 | SOLID/Structure | ○ | 1.0 | Issue 1 identifies multiple responsibilities (inventory, payment, email, QR, notifications) in TicketSalesEngine, recommends decomposition |
| P02 | SOLID/Dependency | ○ | 1.0 | Issue 2 identifies direct PostgreSQL/Redis/Stripe connections, recommends IEventInventoryRepository and IPaymentGateway interfaces |
| P03 | Data Model | ○ | 1.0 | Issue 4 explicitly identifies redundant columns: events.organizer_name/email and tickets.event_title/date/venue_name, proposes SQL normalization |
| P04 | Error Handling/Recovery | ○ | 1.0 | Issue 7 identifies missing compensation logic for partial failures; Issue 10 addresses transaction boundaries with SELECT FOR UPDATE example |
| P05 | State Management | ○ | 1.0 | Issue 8 identifies localStorage risk for JWT tokens, recommends httpOnly cookies with CSRF protection |
| P06 | Test Design/DI | ○ | 1.0 | Issue 3 explicitly addresses "単体テストの方針は未定" and lack of DI framework, recommends tsyringe/InversifyJS |
| P07 | API Quality | ○ | 1.0 | Issue 6 identifies verb-based URLs and provides RESTful alternatives (POST /v1/events, PUT /v1/events/{id}) |
| P08 | Operational Design | ○ | 1.0 | Issue 9 identifies manual environment switching risk, recommends AWS Systems Manager Parameter Store |
| P09 | Module Coupling | ○ | 1.0 | Issue 2 identifies direct EventManager calls and circular dependency risk, recommends interface abstractions |

**Total Detection Score: 9.0 / 9.0**

### Bonus Points

| Bonus ID | Category | Awarded | Evidence |
|----------|----------|---------|----------|
| B01 | SOLID (Auth/Authz separation) | × | Not mentioned |
| B02 | Error classification strategy | ○ | Issue 7 provides ErrorCategory enum with retryable/non-retryable classification |
| B03 | API versioning | ○ | Issue 5 identifies missing API versioning, proposes /v1/ prefix with deprecation policy |
| B04 | Concurrency control | ○ | Issue 10 mentions SELECT FOR UPDATE for concurrent purchase prevention |
| B05 | Error case testing | × | Not mentioned |
| Additional 1 | Cache invalidation | ○ | Issue 11 identifies missing cache invalidation strategy, provides cache-aside pattern implementation |
| Additional 2 | Idempotency | ○ | Issue 12 identifies duplicate purchase risk on retry, proposes idempotency key with Redis caching |
| Additional 3 | Distributed tracing | ○ | Issue 13 identifies lack of trace IDs, recommends AWS X-Ray or OpenTelemetry |

**Bonus Count: 6 items detected**
**Bonus Score: +3.0**

### Penalty Analysis

No penalties detected. Issue 7 mentions "circuit breaker" but frames it appropriately within application-level error handling strategy (疑わしきは罰せず).

**Penalty Score: 0**

### Run 2 Final Score
**12.0** = 9.0 (detection) + 3.0 (bonus) - 0 (penalty)

---

## Comparative Analysis

### Detection Consistency
Both runs achieved perfect detection (9.0/9.0), demonstrating high consistency in identifying all embedded problems.

### Bonus Variability
- Run 1: 8 bonus items (+4.0 after cap)
- Run 2: 6 bonus items (+3.0)
- Difference: Run 1 detected 2 additional structural issues (C-3 Domain layer, M-3 Resilience patterns)

### Stability Assessment
- SD = 0.5 (High Stability)
- Both runs consistently detected all core problems
- Minor variation in bonus detection does not affect core competency

### Notable Differences
1. **Domain Layer Design**: Run 1 (C-3) identified anemic data model issue; Run 2 did not
2. **Resilience Patterns**: Run 1 (M-3) explicitly covered circuit breaker and retry; Run 2 integrated into Issue 7
3. **Presentation**: Run 1 used severity labels (Critical/Significant/Moderate); Run 2 used priority-based categorization
4. **Code Examples**: Run 2 provided more detailed TypeScript implementation examples

Both runs demonstrate strong structural analysis capability with high detection accuracy.
