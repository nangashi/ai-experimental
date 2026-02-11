# Scoring Report: baseline (v009)

## Detection Matrix

| Issue ID | Issue Title | Run1 | Run2 | Notes |
|----------|-------------|------|------|-------|
| P01 | Missing Performance Requirements and SLAs | ○ | ○ | Run1: Issue #11 mentions missing SLOs and performance metrics. Run2: Issue #11 mentions missing SLOs and performance metrics. |
| P02 | N+1 Query Problem in Route Recommendation Service | ○ | ○ | Run1: Issue #1 identifies N+1 query pattern when querying traffic conditions. Run2: Issue #3 identifies N+1 query pattern in route recommendation. |
| P03 | Missing Cache Strategy for Frequently Accessed Data | ○ | ○ | Run1: Issue #7 identifies missing route caching strategy; Issue #1 recommends Redis-based graph cache. Run2: Issue #3 recommends Redis-backed traffic state cache. |
| P04 | Unbounded Historical Query Risk | ○ | ○ | Run1: Issue #9 identifies missing pagination/result limits on analytics endpoint. Run2: Issue #7 identifies missing result limits on analytics queries. |
| P05 | Inefficient Algorithm Complexity for Route Calculation | ○ | ○ | Run1: Issue #13 identifies Dijkstra's algorithm inefficiency, suggests A*. Run2: Issue #1 identifies Dijkstra's algorithm latency issues, suggests A*. |
| P06 | Time-Series Data Growth Without Lifecycle Management | ○ | ○ | Run1: Issue #3 identifies unbounded data growth without retention/archival policies. Run2: Issue #8 identifies pre-aggregated views for analytics optimization. |
| P07 | Missing Database Indexes | ○ | ○ | Run1: Issue #2 identifies missing indexes on SignalAdjustment, RouteRequest tables. Run2: Issue #2 identifies comprehensive missing index strategy. |
| P08 | Real-time WebSocket Scalability Not Addressed | × | × | Neither run mentions WebSocket/persistent connection scalability. |
| P09 | Race Condition in Traffic Signal Control | × | × | Neither run mentions race conditions in Signal Control Service. |
| P10 | Missing Performance Monitoring Metrics | ○ | ○ | Run1: Issue #11 identifies lack of specific performance monitoring metrics. Run2: Issue #11 identifies lack of specific performance monitoring metrics. |

## Bonus Issues

| ID | Category | Issue | Run1 | Run2 | Notes |
|----|----------|-------|------|------|-------|
| B01 | Database Partitioning | Table partitioning for time-series data | ✓ | × | Run1: Issue #3 mentions time-based partitioning for PostgreSQL tables. |
| B02 | Connection Pool Sizing | Database connection pool configuration | ✓ | ✓ | Run1: Issue #6 details connection pool configuration for PostgreSQL/Redis. Run2: Issue #9 details connection pool configuration. |
| B03 | Batch Processing for Analytics | Separate analytical workload | ✓ | ✓ | Run1: Issue #8 recommends read replicas for analytics isolation. Run2: Issue #8 recommends pre-aggregated analytics views and query isolation. |
| B04 | API Rate Limiting Granularity | Differentiated rate limiting strategy | ✓ | × | Run1: Issue #14 recommends tiered rate limiting by operation cost. |
| B05 | Async Processing for Camera Footage | Async processing for media handling | × | × | Neither run mentions S3 camera footage processing pipeline. |
| B06 | Geographic Sharding | Database sharding strategy | × | × | Neither run mentions geographic sharding or city_zone-based sharding. |
| B07 | Read Replica for Analytics | Read replicas for analytics queries | ✓ | ✓ | Run1: Issue #8 mentions read replicas for analytics. Run2: Issue #8 mentions routing analytics to read replica. |
| B08 | Pre-computed Route Cache | Route pre-computation/caching | ✓ | ✓ | Run1: Issue #7 recommends pre-computing popular routes and caching. Run2: Issue #1 recommends pre-computing traffic graph. |
| B09 | Kafka Consumer Lag Alerting | Kafka lag monitoring | ✓ | × | Run1: Issue #8 recommends consumer lag monitoring with specific thresholds. |
| B10 | Auto-scaling Policy | Auto-scaling configuration | × | × | Neither run mentions auto-scaling thresholds or policies. |

## Penalty Issues

| Run | Issue | Category | Reason |
|-----|-------|----------|--------|
| Run1 | Issue #5 - Missing Timeout Configurations | Penalty | Timeout configuration is primarily a reliability concern (failure recovery), not performance. While timeouts prevent thread exhaustion (performance impact), the primary purpose is resilience → reliability scope. Partial penalty: -0.25. |
| Run1 | Issue #15 - Database Connection Reuse and Transaction Management | Penalty | Transaction management discussions about Spring JPA patterns are structural-quality concerns. Connection reuse overlaps with performance (covered in B02), but transaction boundary discussion is architectural pattern → structural-quality scope. Partial penalty: -0.25. |

## Score Calculation

### Run 1
**Detection Score**: 8.0 (P01=1.0, P02=1.0, P03=1.0, P04=1.0, P05=1.0, P06=1.0, P07=1.0, P08=0.0, P09=0.0, P10=1.0)

**Bonus Issues**: 8 detected (B01, B02, B03, B04, B07, B08, B09, capped at 5) = +2.5

**Penalty Issues**: 2 partial penalties (Issue #5: -0.25, Issue #15: -0.25) = -0.5

**Total Score**: 8.0 + 2.5 - 0.5 = **10.0**

### Run 2
**Detection Score**: 8.0 (P01=1.0, P02=1.0, P03=1.0, P04=1.0, P05=1.0, P06=1.0, P07=1.0, P08=0.0, P09=0.0, P10=1.0)

**Bonus Issues**: 4 detected (B02, B03, B07, B08) = +2.0

**Penalty Issues**: 0

**Total Score**: 8.0 + 2.0 - 0.0 = **10.0**

## Summary Statistics
- **Mean Score**: 10.0
- **Standard Deviation**: 0.0
- **Run 1 Score**: 10.0 (detection 8.0 + bonus 2.5 - penalty 0.5)
- **Run 2 Score**: 10.0 (detection 8.0 + bonus 2.0 - penalty 0.0)

## Notes
- Both runs consistently detected 8 out of 10 embedded issues
- P08 (WebSocket scalability) and P09 (race conditions) were not detected in either run
- Run1 identified more bonus issues (8 total, capped at 5) compared to Run2 (4 total)
- Run1 had minor penalties for scope boundary issues (timeout/transaction management discussions)
- High consistency: SD=0.0 indicates very stable performance across runs
