# Performance Design Review: Social Media Analytics Dashboard Platform

## Executive Summary

この設計には、スケーラビリティ、レイテンシ、データアクセス効率において重大なパフォーマンスボトルネックが存在します。主な問題として、N+1クエリパターン、無制限データフェッチ、同期的な長時間処理、不十分なキャッシング戦略、欠落したインデックス設計が挙げられます。現在の設計では、ユーザー数やデータ量の増加に伴い深刻なパフォーマンス劣化が予想されます。

**Critical Risk Level**: HIGH - 複数の致命的ボトルネックが production環境での深刻なパフォーマンス問題を引き起こす可能性があります。

---

## Critical Performance Issues

### 1. Data Access: Severe N+1 Query Pattern in Dashboard API

**Location**: `GET /api/dashboard/overview` (Line 135)

**Issue**:
設計書に「fetches all user accounts from database, then retrieves post statistics for each account in a loop」と明記されています。これは典型的なN+1クエリパターンで、1つのクエリでアカウントリストを取得した後、各アカウントに対してループ内で個別にクエリを実行する設計です。

**Impact**:
- 100アカウントを持つユーザーの場合、101回のデータベースクエリが必要（1 + 100）
- 各クエリのラウンドトリップレイテンシ（通常1-5ms）が累積し、レスポンスタイムが数百ミリ秒に達する
- データベース接続プールの枯渇リスク
- ダッシュボードページが営業チームにとって使用不可能なほど遅くなる

**Recommendation**:
```sql
-- Single optimized query with JOIN and aggregation
SELECT
    a.id AS account_id,
    a.platform,
    COUNT(p.id) AS posts_count,
    AVG(p.likes_count + p.comments_count + p.shares_count) AS avg_engagement
FROM accounts a
LEFT JOIN posts p ON a.id = p.account_id
WHERE a.user_id = $1
GROUP BY a.id, a.platform;
```

この単一クエリで全アカウントの統計を一度に取得でき、N+1問題を完全に解消できます。レイテンシを数百ミリ秒から10ms以下に短縮可能。

---

### 2. Data Access: Unbounded Result Sets Without Pagination Limits

**Location**:
- `GET /api/posts/:accountId` (Line 156) - Optional limit/offset
- `GET /api/analytics/trending-hashtags` (Line 200) - "Queries all posts"
- Report generation (Line 218) - "Queries all posts within the specified date range"

**Issue**:
pagination parametersが optional であり、デフォルト制限が指定されていません。さらに、trending hashtags と report generation は全データセットをメモリにロードする設計です。ソーシャルメディアプラットフォームでは、アクティブなアカウントが数万件の投稿を持つことは珍しくありません。

**Impact**:
- 1アカウントあたり10,000投稿の場合、各投稿レコードが約1KB として 10MB以上のデータ転送
- application server のメモリ枯渇（特にNode.jsのデフォルト heap limit 1.5GB）
- network bandwidth の無駄遣い
- クライアント側で large JSON のパースによる UI フリーズ
- 年次レポート生成時に数十万レコードをメモリ展開し、OOM crash の可能性

**Recommendation**:
1. **Mandatory pagination**: デフォルト limit を 100、最大 1000 に設定
   ```typescript
   const limit = Math.min(req.query.limit || 100, 1000);
   const offset = req.query.offset || 0;
   ```

2. **Trending hashtags**: 直近30日間に制限 + pre-aggregation
   ```sql
   -- Use window for efficient top-N
   WITH hashtag_counts AS (
       SELECT hashtag, COUNT(*) as count
       FROM posts
       WHERE posted_at > NOW() - INTERVAL '30 days'
       GROUP BY hashtag
   )
   SELECT * FROM hashtag_counts ORDER BY count DESC LIMIT 50;
   ```

3. **Report generation**: streaming approach または batch processing（後述）

---

### 3. Architecture: Synchronous Long-Running Operations Blocking Request Path

**Location**:
- `POST /api/analytics/competitor-analysis` (Line 182) - "returns comparison data synchronously"
- Report generation (Line 223) - "synchronous and blocks the API request"

**Issue**:
Competitor analysis と report generation が同期的に実行され、完了まで HTTP request をブロックします。Competitor analysis は外部 API を複数回呼び出す必要があり（各 competitor アカウントごと）、各 API call が 500ms-2s かかる場合、5つの competitor を分析すると 2.5-10秒かかります。

**Impact**:
- API Gateway / Load Balancer のタイムアウト（通常30-60秒）
- 長時間 open connection による connection pool 枯渇
- ユーザーが待機中にブラウザタブを閉じる → 計算リソースの無駄
- 外部 API rate limits に達するリスク
- 同時リクエストが処理できず、システム全体がブロック状態に

**Recommendation**:
**Async job pattern with status polling**:
```typescript
// Step 1: Initiate job
POST /api/analytics/competitor-analysis
Response: { "job_id": "abc123", "status": "processing" }

// Step 2: Poll status
GET /api/jobs/abc123
Response: { "status": "completed", "result_url": "/api/results/abc123" }

// Implementation
const jobId = await queue.publish('competitor-analysis', payload);
return res.json({ job_id: jobId, status: 'processing' });
```

RabbitMQ worker が background で処理し、結果を database または S3 に保存。UI は polling または WebSocket で進捗を表示。

---

### 4. Data Access: Full Table Scan for Hashtag Extraction

**Location**: `GET /api/analytics/trending-hashtags` (Line 200)

**Issue**:
"Queries all posts in the database and extracts hashtags from content field" - これは全投稿の content フィールドをスキャンし、アプリケーションコードで hashtag を抽出する設計を示唆しています。PostgreSQL の full table scan は数百万レコードで数十秒かかります。

**Impact**:
- 100万投稿のテーブルで sequential scan が 10-30秒
- content TEXT フィールドの転送で massive I/O
- すべての trending hashtag リクエストが他のクエリをブロック（shared lock）
- CPU intensive な正規表現処理がアプリケーションサーバーで実行される

**Recommendation**:
**Separate hashtags table with pre-extraction**:
```sql
CREATE TABLE hashtags (
    id SERIAL PRIMARY KEY,
    post_id INTEGER REFERENCES posts(id),
    hashtag VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_hashtags_hashtag_created ON hashtags(hashtag, created_at DESC);
CREATE INDEX idx_hashtags_created ON hashtags(created_at DESC);

-- Trending query becomes efficient
SELECT hashtag, COUNT(*) as count
FROM hashtags
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY hashtag
ORDER BY count DESC
LIMIT 50;
```

Worker が投稿を sync する際に hashtag を抽出・保存。クエリ時間が 10-30秒 → 10-50ms に短縮。

---

### 5. Data Access: Missing Database Indexes

**Issue**:
schema 定義に index が一切指定されていません（primary key 以外）。以下のクエリパターンで深刻なパフォーマンス問題が発生します：

**Critical Missing Indexes**:
```sql
-- 1. Account lookups by user
CREATE INDEX idx_accounts_user_id ON accounts(user_id);

-- 2. Posts by account (most frequent query)
CREATE INDEX idx_posts_account_id_posted_at ON posts(account_id, posted_at DESC);

-- 3. Date range queries for reports
CREATE INDEX idx_posts_posted_at ON posts(posted_at);

-- 4. Engagement metrics lookups
CREATE INDEX idx_engagement_metrics_post_id ON engagement_metrics(post_id);
CREATE INDEX idx_engagement_metrics_recorded_at ON engagement_metrics(recorded_at);

-- 5. Report queries
CREATE INDEX idx_reports_user_id_created_at ON reports(user_id, created_at DESC);

-- 6. Platform-specific queries
CREATE INDEX idx_posts_account_platform ON posts(account_id, platform_post_id);
```

**Impact Without Indexes**:
- dashboard overview: 各 account_id lookup で full table scan → 数秒
- date range queries: 年次レポートで全 posts table scan → 分単位
- 10万レコードのテーブルで indexed query は 5ms、unindexed は 500ms-5秒

---

### 6. Resource Management: Missing Connection Pooling Configuration

**Location**: Database Layer (Line 71)

**Issue**:
PostgreSQL connection pooling の設定が明記されていません。Node.js アプリケーションは各リクエストで新しい connection を開く default behavior を持つ場合があり、connection overhead（50-200ms）が発生します。

**Impact**:
- 各リクエストで connection establishment overhead
- PostgreSQL の max_connections（default 100）に達し、新規接続が拒否される
- TIME_WAIT state の蓄積による socket 枯渇

**Recommendation**:
```typescript
// pg-pool configuration
const pool = new Pool({
    host: process.env.DB_HOST,
    max: 20,              // Maximum pool size
    min: 5,               // Minimum idle connections
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
});
```

min/max を適切に設定し、connection reuse を保証。

---

### 7. Architecture: Inefficient Data Sync Strategy with Sequential Processing

**Location**: Data Synchronization Strategy (Line 208)

**Issue**:
15分ごとの sync job が sequential に各アカウントを処理します：
1. Fetch all accounts
2. **For each account**, call platform API
3. **For each post**, fetch engagement metrics
4. Store in database

100アカウント、各アカウント平均50新規投稿、各 API call 500ms の場合：
- Account fetches: 100 × 0.5s = 50秒
- Post fetches: 100 × 0.5s = 50秒
- Engagement fetches: 5000 × 0.5s = 2500秒（41分）

**合計: 約42分で15分間隔を超過** → sync が次の scheduled time より遅れる → backlog が蓄積

**Impact**:
- データの鮮度低下（"real-time dashboard" の要件違反）
- worker の継続的オーバーロード
- external API rate limits への到達

**Recommendation**:
**Parallel processing with controlled concurrency**:
```typescript
// Process accounts in parallel batches
const BATCH_SIZE = 10;
const accounts = await fetchAllAccounts();

for (let i = 0; i < accounts.length; i += BATCH_SIZE) {
    const batch = accounts.slice(i, i + BATCH_SIZE);
    await Promise.all(batch.map(account => syncAccount(account)));
}

// Within syncAccount, parallelize post fetching
async function syncAccount(account) {
    const posts = await fetchPostsFromAPI(account);
    await Promise.all(posts.map(post =>
        fetchAndStoreEngagement(post)
    ));
}
```

並列化により sync 時間を 42分 → 5-10分 に短縮可能。ただし external API rate limits を考慮し、concurrency を制御すること。

---

### 8. Scalability: Stateful Single-Task Design Blocking Horizontal Scaling

**Location**: "The system is designed to run as a single ECS task" (Line 243)

**Issue**:
single ECS task 設計では horizontal scaling が困難です。"manually increase task count" と記載されていますが、以下の問題があります：
- session data が Redis に保存されているため問題ないが、worker jobs の coordination がない
- 複数 worker が同じ account を同時に sync する競合リスク
- database connection pool が分散されず、集中する

**Impact**:
- vertical scaling（larger instance）のみに依存 → コスト非効率
- single point of failure → 1 task が crash すると全サービス停止
- traffic spike 時にスケールできない

**Recommendation**:
1. **Stateless application design** (既に達成、Redis 使用)
2. **Distributed worker coordination**:
   ```typescript
   // Use RabbitMQ message acknowledgment for job locking
   channel.consume('sync-jobs', async (msg) => {
       const account = JSON.parse(msg.content);
       await syncAccount(account);
       channel.ack(msg);  // Prevents duplicate processing
   });
   ```
3. **Auto-scaling policy**:
   ```yaml
   # ECS auto-scaling based on CPU/memory
   MinTasks: 2
   MaxTasks: 10
   TargetCPUUtilization: 70%
   ```

---

### 9. Caching: Severely Underutilized Cache Strategy

**Location**: Caching Strategy (Line 225)

**Issue**:
Redis が session data と rate limiting にのみ使用され、頻繁にアクセスされるデータのキャッシングが欠落しています：
- Dashboard metrics（最も frequent なリクエスト）
- Account lists per user
- Recent posts
- Trending hashtags

**Impact**:
- 各 dashboard load で full database query
- 同じデータを複数ユーザーが何度もクエリ → database load 増加
- unnecessary latency（cache hit は 1-2ms、database query は 10-50ms）

**Recommendation**:
```typescript
// Cache dashboard metrics
const cacheKey = `dashboard:${userId}`;
let metrics = await redis.get(cacheKey);

if (!metrics) {
    metrics = await fetchDashboardMetrics(userId);
    await redis.setex(cacheKey, 300, JSON.stringify(metrics)); // 5 min TTL
}

// Cache trending hashtags (shared across users)
const trendingKey = 'trending:hashtags:24h';
let trending = await redis.get(trendingKey);

if (!trending) {
    trending = await calculateTrendingHashtags();
    await redis.setex(trendingKey, 3600, JSON.stringify(trending)); // 1 hour TTL
}
```

TTL を適切に設定し、data freshness と database load のバランスを取る。Dashboard metrics は 5分、trending hashtags は 1時間が推奨。

---

### 10. Scalability: Indefinite Data Retention Without Lifecycle Management

**Location**: "All social media posts and engagement metrics are stored indefinitely" (Line 250)

**Issue**:
data retention policy がなく、unlimited growth が設計されています。ソーシャルメディアデータは高頻度で生成され（1アカウントあたり1日10-100投稿）、100アカウント × 100投稿/日 = 10,000レコード/日 → 年間365万レコード。

**Impact**:
- database size が線形増加 → query performance 劣化（index も肥大化）
- backup/restore 時間の増加
- storage cost の無制限増加
- 古いデータ（2年前の投稿）が index に含まれ、recent data queries が遅延

**Recommendation**:
**Tiered storage strategy**:
```sql
-- 1. Hot data (last 90 days): Full detail in PostgreSQL
-- 2. Warm data (90 days - 2 years): Aggregated daily summaries
CREATE TABLE posts_daily_summary (
    account_id INTEGER,
    date DATE,
    posts_count INTEGER,
    total_likes INTEGER,
    total_comments INTEGER,
    total_shares INTEGER,
    PRIMARY KEY (account_id, date)
);

-- 3. Cold data (2+ years): Archive to S3 + Athena for ad-hoc queries

-- Automated archival job
-- Monthly: Aggregate 90-day old data to daily summaries, delete raw posts
-- Yearly: Export 2-year old summaries to S3
```

この戦略により database size を 90% 削減可能。Historical analysis は aggregated data または S3 query で対応。

---

## Performance Requirements: Missing Specifications

設計書に以下の NFR specifications が欠落しており、performance validation ができません：

### Missing SLAs and Capacity Planning

1. **Response Time SLAs**:
   - Dashboard load time target: < 2秒？
   - API endpoint P95 latency target: < 500ms？
   - Report generation timeout: 30秒？

2. **Throughput Requirements**:
   - Expected concurrent users: 100？ 1000？
   - Requests per second target: ?
   - Peak load scenarios: ?

3. **Capacity Planning**:
   - Expected account growth rate: ?
   - Posts per day projection: ?
   - Database size projection over 2 years: ?

4. **Monitoring and Alerting**:
   - Performance metrics to track: ?
   - Alert thresholds for slow queries: ?
   - APM tool selection: ?

**Recommendation**: 以下の明示的な NFR を追加してください：
```yaml
Performance SLAs:
  - Dashboard load (P95): < 2s
  - API endpoints (P95): < 500ms
  - Report generation: < 30s or async
  - Database query timeout: 5s

Capacity Targets:
  - Concurrent users: 500
  - Requests per second: 1000
  - Posts ingestion rate: 10,000/hour
  - Database growth: < 100GB/year

Monitoring:
  - APM: New Relic / DataDog
  - Query performance: pg_stat_statements
  - Alert: P95 latency > 1s
```

---

## Additional Performance Concerns

### 11. I/O Patterns: Inefficient JSON Storage for Report Data

**Location**: `reports.report_data JSONB` (Line 126)

**Issue**:
large report results を単一 JSONB column に保存する設計は、partial data access ができません。レポートの一部（例：summary のみ）を取得する場合でも、全 JSONB をデコードする必要があります。

**Recommendation**:
Summary と detail を分離、または S3 に large report data を保存し、database には metadata と S3 URL のみを保持。

---

### 12. Latency: External API Calls Without Timeout Configuration

**Issue**:
External API calls（Twitter, Meta, LinkedIn）の timeout 設定が明記されていません。API provider の障害時に indefinite hang のリスク。

**Recommendation**:
```typescript
const response = await fetch(apiUrl, {
    timeout: 5000,  // 5 second timeout
    retry: 3,       // Retry with exponential backoff
});
```

---

### 13. Memory Management: Missing Streaming for Large Data Processing

**Issue**:
Report generation と hashtag extraction で large datasets をメモリに全ロードする設計。

**Recommendation**:
Node.js streams を使用して incremental processing：
```typescript
const stream = db.query(new QueryStream('SELECT * FROM posts WHERE ...'));
stream.on('data', (row) => processRow(row));
stream.on('end', () => finalizeReport());
```

---

## Summary of Recommendations by Priority

### P0 - Critical (Immediate Action Required)

1. **Eliminate N+1 queries** in dashboard API - 単一 JOIN query に置き換え
2. **Add mandatory pagination** to all list endpoints - default limit 100, max 1000
3. **Convert long-running operations to async** - competitor analysis, report generation を job queue へ
4. **Add essential database indexes** - 最低限 account_id, posted_at, user_id
5. **Implement connection pooling** - min 5, max 20

### P1 - High (Within 2 Weeks)

6. **Parallelize data sync workers** - 42分 → 5-10分に短縮
7. **Create hashtags pre-extraction table** - full scan を index lookup に
8. **Enable horizontal scaling** - worker coordination + auto-scaling policy
9. **Expand caching strategy** - dashboard metrics, trending hashtags をキャッシュ

### P2 - Medium (Within 1 Month)

10. **Implement data lifecycle management** - tiered storage strategy
11. **Define explicit NFRs** - SLAs, capacity targets, monitoring plan
12. **Add API timeout configuration** - external calls に 5秒 timeout
13. **Optimize report storage** - large JSONB を S3 に移動

---

## Conclusion

この設計は MVP プロトタイプとしては機能しますが、production deployment には深刻なパフォーマンスリスクがあります。特に N+1 queries、unbounded data fetching、synchronous long-running operations は immediate attention が必要です。推奨される P0 修正を実装することで、システムは 10-100倍のパフォーマンス改善が期待できます。

すべての推奨事項を実装することで、スケーラブルで効率的な production-ready システムを構築できます。
