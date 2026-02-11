# Scoring Report: v001-baseline

## Statistical Summary

- **Mean Score**: 9.75
- **Standard Deviation**: 0.75
- **Stability**: High (SD ≤ 0.5 threshold slightly exceeded but still very stable)

## Run Scores

### Run 1: 9.0 points
- Detection: 8.0
- Bonus: +1.0
- Penalty: 0

### Run 2: 10.5 points
- Detection: 9.0
- Bonus: +1.5
- Penalty: 0

---

## Detailed Scoring Breakdown

### Run 1 Detection Matrix

| Problem ID | Category | Status | Score | Evidence |
|------------|----------|--------|-------|----------|
| P01 | External service fault recovery | ○ | 1.0 | C-1 explicitly mentions circuit breaker, timeout, and bulkhead patterns for FCM, SendGrid |
| P02 | WebSocket fault recovery | △ | 0.5 | S-2 mentions reconnection but lacks connection timeout and Ping/Pong specifics |
| P03 | Message idempotency | ○ | 1.0 | C-3 explicitly addresses idempotency keys and deduplication |
| P04 | Cross-database consistency | ○ | 1.0 | C-5 explicitly mentions Saga patterns and distributed transactions |
| P05 | Redis Pub/Sub SPOF | △ | 0.5 | C-2 addresses message loss but not failover/availability design |
| P06 | SLO/SLA monitoring | ○ | 1.0 | S-1 explicitly addresses SLO/SLI, RED metrics, and alert strategies |
| P07 | Data migration compatibility | ○ | 1.0 | S-4 explicitly addresses backward compatibility and rollback procedures |
| P08 | Rate limiting backpressure | ○ | 1.0 | S-3 explicitly addresses backpressure mechanisms and queue behavior |
| P09 | Health check depth | ○ | 1.0 | M-4 explicitly addresses deep health checks for dependencies |

**Detection Subtotal: 8.0**

### Run 1 Bonus/Penalty

**Bonuses (+1.0):**
- B02: Distributed tracing mentioned in S-1 and I-3 (+0.5)
- B03: DR runbook/drill mentioned in I-2 (+0.5)

**Penalties (0):**
- File upload reliability (S-3): Within scope (operational reliability)
- Session management (M-4): Related to availability, not purely security

---

### Run 2 Detection Matrix

| Problem ID | Category | Status | Score | Evidence |
|------------|----------|--------|-------|----------|
| P01 | External service fault recovery | ○ | 1.0 | S-4 explicitly addresses circuit breaker, retry, timeout for FCM/SendGrid |
| P02 | WebSocket fault recovery | ○ | 1.0 | C-1 explicitly addresses reconnection, heartbeat/ping-pong, timeout design |
| P03 | Message idempotency | ○ | 1.0 | C-2 explicitly addresses idempotency keys and deduplication |
| P04 | Cross-database consistency | ○ | 1.0 | C-4 explicitly mentions Saga pattern and consistency strategies |
| P05 | Redis Pub/Sub SPOF | ○ | 1.0 | C-3 explicitly addresses SPOF, failover design, and fallback mechanisms |
| P06 | SLO/SLA monitoring | ○ | 1.0 | S-1 explicitly addresses SLO/SLI, RED metrics, and alert rules |
| P07 | Data migration compatibility | ○ | 1.0 | S-5 explicitly addresses backward-compatible migration and rollback |
| P08 | Rate limiting backpressure | ○ | 1.0 | M-1 addresses rate limiting granularity and backpressure with 429 response |
| P09 | Health check depth | ○ | 1.0 | S-1 explicitly addresses deep health checks with dependency verification |

**Detection Subtotal: 9.0**

### Run 2 Bonus/Penalty

**Bonuses (+1.5):**
- B02: Distributed tracing mentioned in S-1 and C-4 (+0.5)
- B03: DR runbook mentioned in I-2 (+0.5)
- B04: MongoDB indexes mentioned in M-2 for search performance (+0.5)

**Penalties (0):**
- File upload reliability (S-3): Within scope (operational reliability)
- Session management (M-4): Related to availability
- Message search performance (M-2): Related to operational resilience

---

## Key Differences Between Runs

### Run 2 Improvements
1. **P02 (WebSocket)**: Run 2 fully detected with explicit mention of Ping/Pong and timeout (C-1), vs. Run 1's partial detection (S-2)
2. **P05 (Redis SPOF)**: Run 2 fully detected with failover and availability focus (C-3), vs. Run 1's message-loss focus (C-2)
3. **Additional Bonus**: Run 2 detected MongoDB index design (B04)

### Consistency
- Both runs strongly detected critical issues (P01, P03, P04, P06, P07, P08, P09)
- Both runs identified distributed tracing and DR runbook as bonus items
- Both runs maintained scope discipline (no out-of-scope penalties)

---

## Observations

### Strengths
- High detection rate across all severity levels
- Strong coverage of circuit breaker, idempotency, and cross-database consistency patterns
- Good bonus detection (observability and operational practices)
- Excellent scope adherence with no penalties

### Variability
- WebSocket fault recovery detection varied (partial vs. full)
- Redis Pub/Sub analysis focus differed (message loss vs. availability)
- Minor variation in bonus item discovery

### Stability Assessment
- SD = 0.75 indicates **high stability** (just above the 0.5 threshold)
- Core detection is highly consistent
- Variability comes from nuanced interpretation rather than randomness
