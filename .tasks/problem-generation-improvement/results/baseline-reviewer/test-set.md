# Test Scenario Set: security-design-reviewer

Generated for: security-design-reviewer agent
Total scenarios: 7
Capability categories: Threat Modeling, Authentication & Authorization, Data Protection, Input Validation & Attack Defense, Infrastructure & Dependencies

---

## T01: E-Commerce Checkout System

**Difficulty**: Easy
**Category**: Authentication & Authorization Design

### Input

**Design Document: E-Commerce Checkout System**

**Overview**
A web-based checkout system for an online retail platform. Users can add items to cart, apply discount codes, and complete purchases.

**Architecture**
- Frontend: React SPA
- Backend: Node.js (Express) REST API
- Database: PostgreSQL for order data
- Payment: Stripe integration

**Authentication Flow**
- Users authenticate via email/password
- Session tokens stored in HTTP-only cookies
- Session expiration: 24 hours

**Checkout Flow**
1. User reviews cart items
2. User enters shipping address
3. User applies optional discount code
4. User enters payment information (sent to Stripe)
5. Order confirmation displayed

**API Endpoints**
- `POST /api/cart/add` - Add item to cart
- `GET /api/cart` - Retrieve cart contents
- `POST /api/checkout/apply-discount` - Apply discount code
- `POST /api/checkout/complete` - Finalize order

**Database Schema**
- `users`: id, email, password_hash, created_at
- `orders`: id, user_id, total_amount, discount_code, status
- `order_items`: id, order_id, product_id, quantity, price

**Security Considerations**
- Passwords hashed with bcrypt
- HTTPS enforced in production
- SQL queries use parameterized statements

### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T01-C1 | Discount Code Authorization | Identifies lack of user-specific validation on discount codes allowing unlimited reuse or unauthorized access to restricted codes | Mentions discount code validation but lacks specificity about authorization checks or multi-use scenarios | No mention of discount code authorization issues | 1.0 |
| T01-C2 | Price Tampering Prevention | Identifies missing server-side price validation allowing client to manipulate cart item prices before checkout | Mentions need for price validation but lacks detail on server-side enforcement or tampering vectors | No mention of price integrity verification | 1.0 |
| T01-C3 | Session Management Security | Identifies at least two session security issues: excessive 24-hour timeout, lack of session regeneration after privilege change, or missing secure flag specification | Mentions one session security concern but lacks comprehensive coverage | No mention of session security issues | 0.5 |
| T01-C4 | Payment Data Handling | Confirms appropriate use of Stripe integration to avoid PCI DSS scope, notes lack of explicit logging restrictions for payment-related data | Acknowledges Stripe usage reduces risk but lacks detail on data handling policies | No evaluation of payment data security | 0.5 |

### Expected Key Behaviors
- Identify authorization gaps in discount code application (no validation of eligibility, multi-use prevention)
- Detect missing server-side price verification (cart items could be manipulated client-side)
- Recognize session timeout policy may be excessive for financial transactions
- Note lack of rate limiting on checkout endpoints to prevent abuse

### Anti-patterns
- Focusing only on password hashing without evaluating authorization logic
- Accepting parameterized queries as sufficient without examining business logic vulnerabilities
- Overlooking client-server trust boundary issues in e-commerce context
- Generic recommendations without connecting to specific checkout flow risks

---

## T02: Healthcare Patient Portal

**Difficulty**: Medium
**Category**: Data Protection

### Input

**Design Document: Patient Portal System**

**System Overview**
A web portal allowing patients to view medical records, schedule appointments, and communicate with healthcare providers.

**Components**
- Web Application: Next.js
- API Gateway: Kong
- Backend Services: Python (FastAPI)
- Databases:
  - PostgreSQL (patient demographics, appointments)
  - MongoDB (clinical notes, lab results)
- Object Storage: AWS S3 (medical images, documents)
- Cache: Redis (session data)

**User Roles**
- Patient: View own records, schedule appointments
- Provider: View patient records (assigned patients only), create clinical notes
- Admin: User management, system configuration

**Authentication**
- OAuth 2.0 with external identity provider (Okta)
- JWT tokens (15-minute expiration)
- Refresh tokens (7-day expiration)

**Data Storage**
- Patient demographics and appointments in PostgreSQL
- Clinical notes and lab results in MongoDB
- Medical images (DICOM) and PDF documents in S3
- All databases use default encryption settings provided by cloud provider

**API Security**
- Kong validates JWT tokens
- Role-based access control enforced in backend services
- HTTPS/TLS 1.2+ for all communications

**Compliance Requirements**
- HIPAA compliance required
- Data retention: 7 years for medical records
- Audit logs for all access to patient records

**Logging**
- API gateway logs all requests including headers
- Application logs include user ID, timestamp, action, resource accessed
- Logs stored in CloudWatch (90-day retention)

### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T02-C1 | Encryption Key Management | Identifies lack of explicit encryption key management strategy for at-rest data (KMS, key rotation policies, separation of data/key storage) | Mentions encryption concerns but lacks specificity on key management controls | No mention of encryption key management | 1.0 |
| T02-C2 | PHI in Logs | Identifies risk of PHI/PII leakage in API gateway logs (headers may contain tokens, query params) and application logs (resource identifiers may reveal sensitive info) | Mentions logging concerns but lacks specific PHI/PII leakage vectors | No mention of sensitive data in logs | 1.0 |
| T02-C3 | Data Segregation | Identifies lack of tenant isolation mechanisms or patient data segregation controls in shared MongoDB/PostgreSQL instances to prevent cross-patient data access | Mentions multi-tenancy concerns but lacks detail on segregation enforcement | No mention of data isolation requirements | 1.0 |
| T02-C4 | Provider Access Scope | Identifies missing fine-grained authorization details for "assigned patients only" policy (assignment mechanism, dynamic access reviews, emergency access controls) | Mentions provider access control but lacks detail on assignment enforcement | No evaluation of provider authorization model | 0.5 |
| T02-C5 | Audit Log Completeness | Identifies insufficient audit scope missing critical events: authentication failures, role changes, consent modifications, or emergency access overrides | Mentions audit logging but lacks critique of comprehensiveness | Accepts audit logging as adequate without evaluation | 0.5 |

### Expected Key Behaviors
- Identify missing encryption key management strategy (KMS usage, rotation policies)
- Detect PHI/PII leakage risk in verbose logging (headers, query parameters)
- Recognize inadequate data segregation controls for multi-patient environment
- Question 90-day log retention vs 7-year compliance requirement mismatch
- Note lack of emergency access ("break-glass") procedures

### Anti-patterns
- Accepting "default encryption settings" as sufficient without key management evaluation
- Overlooking logging verbosity risks in healthcare context
- Assuming RBAC implementation without examining authorization granularity
- Focusing on transport security while missing at-rest protection gaps

---

## T03: Corporate Expense Reimbursement System

**Difficulty**: Medium
**Category**: Input Validation & Attack Defense

### Input

**Design Document: Expense Reimbursement Platform**

**Purpose**
Enable employees to submit expense reports with receipt attachments for manager approval and finance processing.

**Architecture**
- Frontend: Angular SPA
- Backend: Java Spring Boot
- Database: MySQL
- File Storage: Local filesystem (`/var/uploads/`)
- Email: SendGrid API for notifications

**User Workflow**
1. Employee creates expense report
2. Employee uploads receipt images (JPEG/PNG)
3. Employee submits for approval
4. Manager reviews and approves/rejects
5. Finance processes approved reports
6. System generates reimbursement payment file

**File Upload Implementation**
```java
@PostMapping("/api/expenses/upload")
public ResponseEntity uploadReceipt(@RequestParam("file") MultipartFile file) {
    String filename = file.getOriginalFilename();
    Path filepath = Paths.get("/var/uploads/", filename);
    Files.copy(file.getInputStream(), filepath);
    return ResponseEntity.ok("Uploaded: " + filename);
}
```

**Data Validation**
- Expense amount: Must be positive number
- Date: Must be within last 90 days
- Category: Must match predefined list (travel, meals, supplies, etc.)

**Authorization**
- Employees can only view/edit their own expense reports
- Managers can view reports from their direct reports
- Finance role can view all approved reports

**API Endpoints**
- `POST /api/expenses` - Create expense report
- `POST /api/expenses/upload` - Upload receipt
- `PUT /api/expenses/{id}/approve` - Approve report
- `GET /api/expenses/export` - Export reports to CSV

**Security Measures**
- Input validation on expense amount and date
- File extension check (only .jpg, .png allowed)
- SQL queries use JPA/Hibernate

### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T03-C1 | Path Traversal Vulnerability | Identifies path traversal risk in file upload using unsanitized `originalFilename` allowing directory traversal attacks (e.g., `../../etc/passwd`) | Mentions filename validation concerns but lacks specific path traversal attack vector | No mention of path traversal risk | 1.0 |
| T03-C2 | File Type Validation Bypass | Identifies inadequate file validation relying only on extension check, missing content-type verification, magic byte validation, or file size limits | Mentions file validation but lacks detail on bypass techniques or defense-in-depth | No critique of file validation approach | 1.0 |
| T03-C3 | CSV Injection in Export | Identifies CSV injection risk in export functionality where expense descriptions/categories could contain formula injection payloads (=, +, -, @) | Mentions export security or output encoding but lacks specific CSV injection vector | No mention of export-related vulnerabilities | 1.0 |
| T03-C4 | Authorization Enforcement | Identifies missing authorization checks on upload endpoint allowing any authenticated user to upload files, or lack of ownership verification linking uploads to expense reports | Mentions authorization concerns but lacks specificity on endpoint-level enforcement gaps | No evaluation of authorization implementation | 0.5 |
| T03-C5 | File Storage Security | Identifies at least two file storage risks: direct filesystem access bypassing application logic, missing access controls on upload directory, or lack of malware scanning | Mentions one file storage concern but lacks comprehensive coverage | No mention of file storage security | 0.5 |

### Expected Key Behaviors
- Identify path traversal vulnerability in filename handling
- Detect inadequate file type validation (extension-only check)
- Recognize CSV injection risk in export functionality
- Note missing authorization check on upload endpoint
- Recommend virus/malware scanning for uploaded files

### Anti-patterns
- Accepting extension-based validation as sufficient
- Overlooking output encoding issues in export functions
- Assuming JPA/Hibernate usage prevents all injection attacks
- Missing filesystem-level security concerns (permissions, access controls)

---

## T04: Social Media Analytics Dashboard

**Difficulty**: Hard
**Category**: Threat Modeling (STRIDE)

### Input

**Design Document: Social Media Analytics Dashboard**

**Product Description**
A SaaS platform that aggregates social media data from Twitter, Facebook, and Instagram APIs to provide brand sentiment analysis and engagement metrics.

**Architecture**
- Frontend: Vue.js SPA (dashboard)
- API Gateway: AWS API Gateway + Lambda
- Data Pipeline:
  - Ingestion: Python workers pulling from social media APIs every 15 minutes
  - Processing: Apache Kafka + Spark Streaming
  - Storage: ClickHouse (time-series analytics), Elasticsearch (search)
- Cache: Redis (API responses, user sessions)
- Authentication: Custom JWT implementation

**User Tiers**
- Free: 1 connected account, 30-day data history
- Pro: 5 connected accounts, 1-year data history, API access
- Enterprise: Unlimited accounts, unlimited history, API access, SSO integration

**Data Flow**
1. User connects social media accounts via OAuth (credentials stored in PostgreSQL)
2. Background workers fetch posts/metrics every 15 minutes
3. Data processed through Kafka, enriched with sentiment analysis (AWS Comprehend)
4. Aggregated metrics stored in ClickHouse
5. Dashboard displays real-time analytics via WebSocket connection

**API Design**
- Public API for Pro/Enterprise customers
- Rate limiting: 100 req/hour (Free), 1000 req/hour (Pro), 10000 req/hour (Enterprise)
- API keys generated on user request (32-character random string)

**Security Measures**
- HTTPS for all communications
- JWT tokens for session management (custom implementation using HS256)
- Social media OAuth tokens encrypted in database
- API rate limiting by tier
- CORS enabled for dashboard domain

**Data Handling**
- Social media posts cached in Redis (1-hour TTL)
- Full text search in Elasticsearch (no encryption)
- Analytics queries use ClickHouse materialized views
- Data deletion: User can disconnect accounts (removes future data collection, historical data retained)

**Monitoring**
- CloudWatch metrics for API latency, error rates
- Application logs to CloudWatch Logs
- Alerts for service disruptions

### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T04-C1 | STRIDE Threat Coverage | Systematically addresses at least 4 of 6 STRIDE categories with specific issues: Spoofing (JWT implementation), Tampering (data integrity), Repudiation (audit gaps), Information Disclosure (encryption gaps), Denial of Service (rate limit bypass), Elevation of Privilege (tier enforcement) | Addresses 2-3 STRIDE categories with specific concerns | Generic security mentions without STRIDE framework application | 1.0 |
| T04-C2 | Custom JWT Implementation Risks | Identifies specific cryptographic weaknesses in custom JWT implementation (HS256 key management, lack of token rotation/revocation, missing signature verification details, or algorithm confusion risks) | Mentions JWT concerns but lacks cryptographic specificity | No critique of JWT implementation | 1.0 |
| T04-C3 | Social Media Token Protection | Identifies inadequate protection for stored OAuth tokens beyond encryption (key management, token refresh strategy, breach detection, separation of encryption keys from data) | Mentions token encryption but lacks detail on protection strategy | Accepts encryption as sufficient without further analysis | 1.0 |
| T04-C4 | Data Retention and Privacy | Identifies privacy risks in "historical data retained" policy (GDPR right to erasure, data minimization principles, lack of retention limits, user consent model) | Mentions data retention concerns but lacks regulatory or privacy framework connection | No evaluation of data retention policy | 1.0 |
| T04-C5 | Tier Privilege Escalation | Identifies mechanisms for tier privilege escalation or enforcement gaps (API key shared across tiers, rate limit bypass via multiple keys, WebSocket connection not tier-restricted, cached data accessible across tiers) | Mentions tier enforcement but lacks specific escalation vectors | No analysis of tier boundary enforcement | 0.5 |
| T04-C6 | Third-Party Data Exposure | Identifies risks in social media data handling (cached posts in Redis accessible without encryption, Elasticsearch unencrypted full-text content, no data classification policy, cross-tenant data leakage in shared infrastructure) | Mentions data encryption gaps but lacks multi-tenancy or exposure analysis | No evaluation of third-party data protection | 0.5 |

### Expected Key Behaviors
- Apply STRIDE framework systematically to identify threat categories
- Identify cryptographic weaknesses in custom JWT implementation
- Question encryption strategy for OAuth tokens (key management, rotation)
- Recognize GDPR/privacy issues with indefinite data retention
- Detect tier enforcement gaps (API keys, rate limits, data access)
- Note unencrypted data in Redis and Elasticsearch

### Anti-patterns
- Generic security checklist without threat modeling structure
- Accepting "encrypted in database" without examining key management
- Overlooking data retention and privacy implications
- Missing multi-tenancy concerns in shared infrastructure
- Focusing on transport security while ignoring at-rest protection

---

## T05: IoT Device Fleet Management

**Difficulty**: Hard
**Category**: Infrastructure & Dependencies

### Input

**Design Document: IoT Fleet Management Platform**

**Overview**
A cloud platform for managing and monitoring industrial IoT sensors deployed in manufacturing facilities.

**System Components**
- Device Gateway: MQTT broker (Eclipse Mosquitto)
- Backend API: Go microservices
- Device Registry: PostgreSQL
- Time-series data: InfluxDB
- Message Queue: RabbitMQ
- Container Orchestration: Kubernetes (EKS)
- Secrets Management: Kubernetes Secrets for DB credentials
- Monitoring: Prometheus + Grafana

**Device Communication**
- Devices connect via MQTT over TLS
- Device authentication: X.509 certificates
- Certificate authority: Self-hosted CA (OpenSSL)
- Telemetry published to topics: `devices/{device_id}/telemetry`
- Commands sent to topics: `devices/{device_id}/commands`

**Certificate Lifecycle**
- Certificates generated at device provisioning (10-year validity)
- Certificate revocation: CRL updated monthly
- Devices check CRL on reconnection

**API Architecture**
- REST API for device management (create, update, delete devices)
- WebSocket API for real-time telemetry streaming
- API authentication: Bearer tokens (JWT)
- API authorization: Role-based (admin, operator, viewer)

**Data Storage**
- Device metadata: PostgreSQL (hostname, location, firmware version)
- Telemetry data: InfluxDB (temperature, pressure, vibration readings)
- Configuration: Kubernetes ConfigMaps (MQTT broker URLs, API endpoints)
- Credentials: Kubernetes Secrets (database passwords, API keys)

**Deployment**
- Kubernetes namespaces separate dev/staging/prod
- Services deployed via Helm charts
- CI/CD: GitHub Actions with kubectl apply
- Docker images pulled from private Docker Hub repository

**Dependency Management**
- Base images: `alpine:latest`
- Application dependencies managed via Go modules
- No automated vulnerability scanning
- Manual updates quarterly

**Network Architecture**
- MQTT broker exposed via LoadBalancer service (port 8883)
- REST API exposed via Ingress controller
- InfluxDB and PostgreSQL as ClusterIP services (internal only)
- No network policies defined

### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T05-C1 | Certificate Management Lifecycle | Identifies at least three certificate security issues: excessive 10-year validity period, slow CRL update cycle (monthly), lack of automated revocation distribution, or missing OCSP support | Identifies 1-2 certificate management concerns but lacks comprehensive lifecycle analysis | No critique of certificate management approach | 1.0 |
| T05-C2 | Secrets Management Security | Identifies Kubernetes Secrets inadequacy for production secrets (base64 encoding only, not encrypted at rest by default, etcd exposure) and recommends external secret manager (Vault, AWS Secrets Manager, etc.) | Mentions secrets security concerns but lacks specificity on Kubernetes Secrets limitations | Accepts Kubernetes Secrets as sufficient | 1.0 |
| T05-C3 | Container Image Security | Identifies multiple image security risks: using `latest` tag prevents reproducibility, Alpine base may have vulnerabilities, lack of image signing/verification, missing vulnerability scanning in CI/CD | Mentions image security but lacks detail on specific risks or comprehensive controls | No evaluation of container image security practices | 1.0 |
| T05-C4 | Network Segmentation | Identifies missing network policies allowing unrestricted pod-to-pod communication, risk of lateral movement between namespaces, lack of egress controls, or insufficient database access restrictions | Mentions network security but lacks specific Kubernetes network policy analysis | No mention of network segmentation or isolation | 1.0 |
| T05-C5 | Dependency Vulnerability Management | Identifies inadequate quarterly manual updates, lack of automated vulnerability scanning (Snyk, Trivy, etc.), missing dependency pinning, or absence of SBOM for supply chain risk management | Mentions dependency concerns but lacks detail on vulnerability management process | No evaluation of dependency security practices | 0.5 |
| T05-C6 | MQTT Authorization Model | Identifies lack of topic-level authorization controls allowing devices to subscribe to other devices' command topics or publish to arbitrary topics beyond their device_id | Mentions MQTT security but lacks specific authorization enforcement analysis | No evaluation of MQTT topic access controls | 0.5 |

### Expected Key Behaviors
- Identify excessive certificate validity period and slow revocation mechanisms
- Recognize Kubernetes Secrets limitations for production secret management
- Detect container image security issues (latest tag, missing scanning, no signing)
- Note absence of Kubernetes network policies for pod isolation
- Question quarterly manual dependency updates vs automated scanning
- Identify MQTT topic-level authorization gaps

### Anti-patterns
- Accepting X.509 authentication without examining full PKI lifecycle
- Assuming Kubernetes Secrets are sufficient for production environments
- Overlooking container supply chain security (image provenance, scanning)
- Missing network-level security controls in Kubernetes context
- Focusing on TLS encryption while ignoring authorization and access control

---

## T06: Content Management System with Multi-Language Support

**Difficulty**: Medium
**Category**: Input Validation & Attack Defense

### Input

**Design Document: Multilingual CMS Platform**

**Product Overview**
A content management system supporting multiple languages for global marketing teams to create and publish website content.

**Technical Stack**
- Frontend: React with i18n library
- Backend: Ruby on Rails
- Database: PostgreSQL with jsonb columns for translations
- CDN: CloudFront for static assets
- Search: Algolia for content search

**Content Model**
- Articles: title, body (rich text), author, publish_date, status (draft/published)
- Translations: stored as jsonb column with language codes as keys
  ```json
  {
    "en": {"title": "...", "body": "..."},
    "es": {"title": "...", "body": "..."},
    "ja": {"title": "...", "body": "..."}
  }
  ```

**Rich Text Editor**
- CKEditor integration for content authoring
- Supports formatting, links, embedded images
- Content stored as HTML in database
- Preview functionality renders HTML in iframe

**User Roles**
- Author: Create and edit own articles
- Editor: Review and publish articles
- Admin: All permissions plus user management

**Content Publishing Flow**
1. Author creates article in default language
2. Author or translator adds translations
3. Editor reviews content
4. Editor publishes (status changed to 'published')
5. Published content synced to CDN
6. Search index updated via webhook to Algolia

**API Endpoints**
- `POST /api/articles` - Create article
- `PUT /api/articles/:id` - Update article
- `PUT /api/articles/:id/translate` - Add/update translation
- `POST /api/articles/:id/publish` - Publish article
- `GET /api/articles/search?q=query` - Search articles

**Security Measures**
- Authentication via Devise gem
- Authorization via Pundit gem
- CSRF protection enabled
- Content Security Policy (CSP): `script-src 'self' 'unsafe-inline'`

**Input Handling**
- Title and body sanitized using Rails sanitize helper
- Search queries parameterized in SQL
- File uploads restricted to images (JPEG, PNG, GIF)

### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T06-C1 | Stored XSS in Rich Text Content | Identifies stored XSS risk from inadequate HTML sanitization in rich text body, especially with CKEditor's flexible formatting and CSP 'unsafe-inline' allowing script execution | Mentions XSS concerns but lacks connection to rich text context or CSP weakness | No identification of XSS vulnerability | 1.0 |
| T06-C2 | Injection via Translation JSON | Identifies injection risks in jsonb translation storage (second-order SQL injection if translations extracted and used in dynamic queries, or XSS if translation values not escaped on render) | Mentions JSON storage concerns but lacks specific injection vectors | No evaluation of translation data security | 1.0 |
| T06-C3 | Search Query Injection | Identifies Algolia search query injection risks or lack of input validation on search parameters allowing filter bypass or data exposure through query manipulation | Mentions search security but lacks specific query injection analysis | No mention of search-related vulnerabilities | 0.5 |
| T06-C4 | Iframe Sandbox Escape | Identifies risks in preview iframe implementation (missing sandbox attribute, same-origin context allowing parent page access, or lack of CSP for preview) | Mentions preview concerns but lacks iframe security specifics | No evaluation of preview functionality security | 1.0 |
| T06-C5 | CDN Cache Poisoning | Identifies cache poisoning risks through language parameter manipulation, cache key insufficient granularity, or lack of Vary headers causing wrong-language content delivery | Mentions CDN concerns but lacks specific cache poisoning vectors | No mention of CDN security | 0.5 |

### Expected Key Behaviors
- Identify stored XSS vulnerability in rich text HTML storage with weak CSP
- Recognize injection risks in jsonb translation data
- Detect potential search query manipulation in Algolia integration
- Note missing iframe sandbox restrictions in preview functionality
- Consider cache poisoning scenarios in multi-language CDN setup

### Anti-patterns
- Assuming Rails sanitize helper fully prevents XSS without examining CSP
- Overlooking second-order injection from stored JSON data
- Accepting third-party search integration without input validation analysis
- Missing client-side security controls (iframe sandbox, CSP directives)
- Focusing on SQL injection while missing other injection attack surfaces

---

## T07: Real-Time Bidding Platform

**Difficulty**: Hard
**Category**: Authentication & Authorization Design

### Input

**Design Document: Real-Time Advertising Bidding Platform**

**System Purpose**
A platform for advertisers to bid on ad placements in real-time auctions triggered by user page views.

**High-Level Architecture**
- Bid Service: Handles incoming bid requests from ad exchanges (1M req/min expected)
- Auction Engine: Evaluates bids and selects winner (sub-50ms latency requirement)
- Campaign Management API: CRUD operations for advertiser campaigns
- Reporting API: Campaign performance metrics
- Database: MongoDB (campaign configs), Redis (active campaigns cache), Cassandra (bid/impression logs)

**User Types**
1. **Advertisers**: Create campaigns, set budgets, view reports
2. **Account Managers**: Manage multiple advertiser accounts, adjust campaigns on behalf of clients
3. **Platform Admins**: System configuration, user management

**Authentication Design**
- Advertisers & Account Managers: Username/password with JWT tokens (1-hour expiration)
- Ad Exchanges: API key authentication (static keys, rotated annually)
- Inter-service: mTLS with service mesh (Istio)

**Authorization Model**
- Advertisers can access only their own campaigns and reports
- Account Managers can access campaigns for accounts assigned to them (assignment table in PostgreSQL)
- Platform Admins have full access
- Authorization checks performed in each microservice using user context from JWT

**Campaign Management API**
- `POST /campaigns` - Create campaign (requires budget, target criteria, bid amount)
- `PUT /campaigns/{id}` - Update campaign (can modify budget, bid amount)
- `DELETE /campaigns/{id}` - Delete campaign
- `GET /campaigns/{id}/report` - Retrieve performance metrics

**Bid Service Flow**
1. Ad exchange sends bid request (user context, placement info)
2. Bid service queries Redis for matching active campaigns
3. For each match, auction engine calculates bid
4. Highest bid returned to exchange (if exceeds floor price)
5. Win/loss logged to Cassandra

**Budget Enforcement**
- Daily budgets stored in campaign config
- Current spend tracked in Redis (incremented on win notifications)
- Campaign deactivated when spend >= budget (background job runs every 5 minutes)

**Security Considerations**
- JWT tokens include user_id, role, account_assignments
- API keys stored hashed in database
- Rate limiting: 100 req/min per advertiser, 10000 req/min per ad exchange
- All traffic over HTTPS
- MongoDB and Cassandra use application-level encryption for sensitive fields (credit card data)

**Monitoring & Compliance**
- Audit logs for campaign creation/modification (user_id, timestamp, action)
- Bid request/response logged for 30 days
- GDPR compliance: user IP addresses hashed before storage

### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T07-C1 | Account Manager Authorization Enforcement | Identifies TOCTOU race condition in account manager authorization (assignment table in PostgreSQL may be out of sync with JWT claims, allowing access after de-assignment) or lack of real-time assignment validation | Mentions account manager authorization but lacks specific enforcement gap analysis | No evaluation of account manager access control | 1.0 |
| T07-C2 | Campaign Budget Race Conditions | Identifies race conditions in budget enforcement (5-minute check interval allows overspend, Redis increment not atomic with bid submission, distributed system consistency issues) | Mentions budget concerns but lacks specific race condition or consistency analysis | No critique of budget enforcement mechanism | 1.0 |
| T07-C3 | JWT Token Privilege Escalation | Identifies risks in embedding authorization data (account_assignments) in JWT: stale permissions after reassignment, lack of token revocation mechanism, or excessive token lifetime for high-value operations | Mentions JWT concerns but lacks specific privilege escalation or staleness vectors | No analysis of JWT authorization model | 1.0 |
| T07-C4 | Inter-Service Authorization | Identifies missing fine-grained inter-service authorization (mTLS provides authentication but lacks operation-level authorization, service mesh policies undefined, or principle of least privilege violations) | Mentions service-to-service security but lacks authorization specificity | No evaluation of microservice authorization | 0.5 |
| T07-C5 | Ad Exchange API Key Management | Identifies weaknesses in static API key rotation (annual rotation insufficient, no emergency revocation process, lack of key usage monitoring, or shared keys across exchange endpoints) | Mentions API key concerns but lacks comprehensive key lifecycle analysis | Accepts API key authentication without critique | 0.5 |
| T07-C6 | Audit Trail for Financial Operations | Identifies insufficient audit logging for financial events (budget modifications, bid amount changes, spend tracking adjustments) missing critical fields like before/after values, IP address, or lack of immutability guarantees | Mentions audit logging but lacks financial operation specificity | No evaluation of audit completeness | 0.5 |

### Expected Key Behaviors
- Identify TOCTOU issues in account manager assignment validation
- Recognize race conditions in budget enforcement with 5-minute intervals
- Detect privilege escalation risks from stale JWT claims
- Note missing operation-level authorization in service mesh
- Question annual API key rotation adequacy for high-volume exchanges
- Identify gaps in financial audit trail (budget changes, bid modifications)

### Anti-patterns
- Accepting mTLS as complete inter-service security without authorization analysis
- Overlooking distributed system consistency challenges in real-time bidding
- Missing time-of-check vs time-of-use vulnerabilities in authorization
- Assuming JWT tokens are sufficient without examining revocation and staleness
- Focusing on authentication mechanisms without evaluating authorization enforcement
