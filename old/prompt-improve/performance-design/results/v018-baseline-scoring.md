# Scoring Results: baseline (Round 18)

## Run 1 Scoring

### Detection Matrix

| Problem ID | Category | Detection | Score | Notes |
|-----------|----------|-----------|-------|-------|
| P01 | パフォーマンス要件/SLA未定義 | ○ | 1.0 | Issue #12 "Missing Performance Monitoring and Observability" + Issue #11 "No Service Level Objectives (SLOs) Defined" explicitly identify lack of performance SLAs and monitoring strategy |
| P02 | N+1クエリ問題 | ○ | 1.0 | Issue #1 "N+1 Query Pattern in Dashboard Overview" directly identifies the N+1 problem with JOIN/aggregation solution |
| P03 | キャッシュ戦略の不明瞭さ | ○ | 1.0 | Issue #9 "Missing Cache Strategy for Frequently Accessed Data" identifies lack of caching for dashboard/trending data and proposes cache invalidation strategy |
| P04 | レポート生成の同期処理 | ○ | 1.0 | Issue #3 "Synchronous Blocking Operations in Request Path" explicitly covers report generation (line 223) with async job pattern recommendation |
| P05 | データ同期のAPI呼出し効率 | △ | 0.5 | Issue #4 mentions "For each post, fetch engagement metrics" but focuses on parallelization rather than batch API usage |
| P06 | トレンドハッシュタグ分析のクエリ効率 | ○ | 1.0 | Issue #6 "Full-Text Hashtag Extraction on Every Query" identifies full-table scan and proposes hashtags table with pre-computation |
| P07 | インデックス設計の欠如 | ○ | 1.0 | Issue #5 "Missing Indexes on Critical Query Paths" lists specific index candidates (account_id, posted_at, etc.) |
| P08 | 無期限データ保持による容量増大 | ○ | 1.0 | Issue #8 "Indefinite Data Retention Without Archival Strategy" proposes TimescaleDB partitioning and retention policies |
| P09 | 競合分析APIの同期処理 | ○ | 1.0 | Issue #3 explicitly covers competitor analysis endpoint (line 198) with async job recommendation |

**Detection Subtotal**: 8.5 / 9.0

### Bonus Issues

| ID | Description | Valid | Score |
|----|-------------|-------|-------|
| B01 | Connection pooling configuration | Yes | +0.5 | Issue #7 "No Connection Pooling Strategy Defined" with detailed configuration recommendations |
| B02 | API Gateway caching | Yes | +0.5 | Issue #18 "Missing CDN Cache Configuration" mentions CloudFront API response caching |
| B03 | Horizontal scaling strategy | Yes | +0.5 | Issue #13 "Stateful Single-Task Architecture Blocks Horizontal Scaling" proposes ECS autoscaling |
| B04 | Background job parallelization | Yes | +0.5 | Issue #10 "Sequential API Processing Instead of Parallelization" with concurrency control pattern |
| B05 | Performance monitoring metrics | Yes | +0.5 | Issue #12 covers P50/P95/P99 response times, database query latency, job processing time, cache hit rates |

**Bonus Subtotal**: +2.5 (capped at 5 items)

### Penalties

No out-of-scope or factually incorrect issues detected. All issues are performance-related and evidence-based.

**Penalty Subtotal**: 0

### Run 1 Total Score

**Run1 = 8.5 (detection) + 2.5 (bonus) - 0 (penalty) = 11.0**

---

## Run 2 Scoring

### Detection Matrix

| Problem ID | Category | Detection | Score | Notes |
|-----------|----------|-----------|-------|-------|
| P01 | パフォーマンス要件/SLA未定義 | ○ | 1.0 | Issue #11 "No Service Level Objectives (SLOs) Defined" + Issue #10 "Missing Performance Monitoring and Observability" explicitly address lack of SLOs and monitoring |
| P02 | N+1クエリ問題 | ○ | 1.0 | Issue #1 "N+1 Query Pattern in Dashboard Overview API" identifies the problem with JOIN-based solution |
| P03 | キャッシュ戦略の不明瞭さ | ○ | 1.0 | Issue #8 "Inadequate Caching Strategy for High-Frequency Reads" identifies lack of caching for dashboard/trending data with smart invalidation strategy |
| P04 | レポート生成の同期処理 | ○ | 1.0 | Issue #5 "Synchronous Report Generation Blocking API Requests" with async job pattern and chunked processing |
| P05 | データ同期のAPI呼出し効率 | △ | 0.5 | Issue #4 "N+1 Query Pattern in Data Synchronization Workers" mentions "For each post, fetch engagement metrics" but primarily addresses parallelization not batch API usage |
| P06 | トレンドハッシュタグ分析のクエリ効率 | ○ | 1.0 | Issue #3 "Full-Table Scan for Trending Hashtag Analysis" identifies full-table scan with hashtags table and pre-aggregation solution |
| P07 | インデックス設計の欠如 | × | 0.0 | No dedicated section on missing indexes. Issue #2 mentions indexes briefly in context but doesn't focus on general index strategy |
| P08 | 無期限データ保持による容量増大 | ○ | 1.0 | Issue #6 "Unbounded Data Growth Without Archival Strategy" with TimescaleDB partitioning and tiered storage recommendations |
| P09 | 競合分析APIの同期処理 | ○ | 1.0 | Issue #2 "Synchronous Competitor Analysis with Real-Time API Calls" with detailed async job pattern |

**Detection Subtotal**: 7.5 / 9.0

### Bonus Issues

| ID | Description | Valid | Score |
|----|-------------|-------|-------|
| B01 | Connection pooling configuration | Yes | +0.5 | Issue #7 "Missing Connection Pooling and Resource Management" with detailed pool configuration |
| B02 | API Gateway caching | No | 0 | Not mentioned |
| B03 | Horizontal scaling strategy | Yes | +0.5 | Issue #9 "No Horizontal Scalability Architecture" with ECS autoscaling and load balancer config |
| B04 | Background job parallelization | Yes | +0.5 | Issue #4 includes parallel processing pattern with Promise.all batching |
| B05 | Performance monitoring metrics | Yes | +0.5 | Issue #10 comprehensively covers API/DB/worker/cache metrics with OpenTelemetry examples |
| - | Engagement metrics denormalization | Yes | +0.5 | Issue #12 "Optimize Engagement Metrics Storage" proposes denormalization performance improvement |

**Bonus Subtotal**: +2.5 (capped at 5 items)

### Penalties

No out-of-scope or factually incorrect issues detected. All issues are performance-related and evidence-based.

**Penalty Subtotal**: 0

### Run 2 Total Score

**Run2 = 7.5 (detection) + 2.5 (bonus) - 0 (penalty) = 10.0**

---

## Summary

**baseline**: Mean=10.5, SD=0.5

Run1=11.0(検出8.5+bonus5-penalty0), Run2=10.0(検出7.5+bonus5-penalty0)

### Key Differences Between Runs

- **Run1** detected all 9 core problems (8.5/9.0 with P05 as partial)
- **Run2** missed P07 (index design) as a dedicated issue, resulting in 7.5/9.0
- Both runs earned maximum bonus (+2.5 capped)
- Both runs had zero penalties
- **Standard deviation (0.5)** indicates high stability

### Notable Strengths

- Consistent detection of critical issues (N+1 queries, sync operations, caching)
- Strong bonus coverage (connection pooling, monitoring, autoscaling)
- Zero false positives or out-of-scope issues
- Detailed remediation proposals with code examples

### Areas for Improvement

- Run2 missed explicit index design section (embedded in other issues)
- P05 (batch API usage) detected partially in both runs - primarily addressed parallelization
