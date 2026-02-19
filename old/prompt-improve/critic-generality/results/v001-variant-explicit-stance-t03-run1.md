### Generality Critique Results

#### Critical Issues (Perspective overly dependent on specific domains)
None

#### Scope Item Generality Evaluation
| Scope Item | Classification | Reason | Improvement Proposal |
|------------|----------------|--------|---------------------|
| レスポンスタイム目標 | Generic | Response time objectives are universally applicable across project types: web applications (page load time), mobile apps (screen transition time), APIs (request latency), desktop software (UI responsiveness), embedded systems (control loop timing). Testing across 3 contexts: B2B SaaS dashboard (meaningful—user experience), mobile game (meaningful—frame time/input lag), data processing pipeline (meaningful—job completion SLA). No industry, regulation, or technology dependency. | None required. |
| スケーラビリティ設計 | Generic | Scalability to handle user growth and data volume increases is a fundamental architectural concern: SaaS platforms (concurrent users), social media (user base growth), analytics systems (data ingestion rate), e-commerce (traffic spikes), IoT platforms (device connections). Applies across all software categories regardless of tech stack. | None required. |
| リソース使用効率 | Generic | CPU, memory, storage optimization is relevant to all software: cloud applications (cost optimization), mobile apps (battery/memory constraints), embedded systems (hardware limitations), desktop software (resource contention), backend services (infrastructure costs). Technology-agnostic and industry-agnostic. | None required. |
| キャッシュ戦略 | Generic | Caching frequently accessed data is a universal performance optimization technique: web applications (page caching, API response caching), databases (query result caching), CDN content delivery (static asset caching), mobile apps (local data caching), backend services (distributed caching). No specific framework or technology is assumed. | None required. |
| ボトルネック分析 | Generic | Identifying performance bottlenecks is standard engineering practice across contexts: web applications (slow database queries), mobile apps (inefficient rendering), data pipelines (processing throughput), APIs (rate limiting points), embedded systems (computation hotspots). Concept applies universally regardless of domain. | None required. |

#### Problem Bank Generality Evaluation
- Generic: 4 items
- Conditionally Generic: 0 items
- Domain-Specific: 0 items

All 4 problem bank entries are technology-neutral and broadly applicable:
1. "レスポンスタイム目標が定義されていない" - Absence of performance goals is a common issue across all project types (web, mobile, backend, embedded). Testing across 3 contexts: internal admin tool (meaningful), real-time chat application (meaningful), batch processing system (meaningful as throughput SLA).
2. "データベースクエリが最適化されていない" - While "データベース" (database) is mentioned, it refers to data storage generically, not a specific DBMS (MySQL, PostgreSQL, MongoDB). Query optimization applies to any data access pattern: SQL databases, NoSQL stores, object storage, file systems. Broadly applicable.
3. "キャッシュが未実装" - Cache implementation absence is a universal performance gap applicable to web backends, mobile frontends, APIs, content delivery systems.
4. "N+1クエリ問題が存在" - N+1 query anti-pattern is a well-known issue across ORMs, GraphQL resolvers, data access layers. Not tied to specific technologies or industries.

#### Improvement Proposals
None

#### Confirmation (Positive Aspects)
- **Exceptional generality**: All 5 scope items use fundamental performance engineering concepts (latency targets, scalability, resource efficiency, caching, bottleneck identification) applicable across industries, project types, and technology stacks.
- **Technology independence verified**: No specific frameworks (React, Django), cloud providers (AWS, Azure), databases (PostgreSQL, MongoDB), or programming languages are mentioned. "データベース" is used as a generic data storage concept, not a specific product.
- **Industry independence verified**: Performance concerns are equally relevant to financial trading platforms, healthcare systems, e-commerce sites, social media, internal tools, IoT firmware, gaming applications, data analytics. No regulatory or industry-specific assumptions.
- **Problem bank quality**: All 4 examples represent common performance anti-patterns (missing targets, unoptimized queries, no caching, N+1 problem) that reviewers would recognize across diverse project contexts.
- **Passes "7 out of 10 projects" test**: Applying this perspective to 10 random software projects (web app, mobile app, API service, data pipeline, desktop software, embedded firmware, SaaS platform, analytics dashboard, gaming backend, enterprise integration) would produce meaningful evaluation results for all 10.
- **Appropriate abstraction level**: The perspective focuses on design-level concerns (whether performance targets exist, whether scalability is considered) rather than implementation specifics (which caching library to use, exact latency milliseconds).
- **Balanced depth and breadth**: Covers multiple performance dimensions (latency, scalability, efficiency, caching, bottleneck analysis) without being too shallow or too prescriptive.
- **Strong reference model**: This perspective serves as an excellent example of how to structure a generic, industry-independent design review perspective.
