# Test Scenario Set: security-design-reviewer

Generated using: v001-variant-type-bank-hybrid
Agent Type: Type-A (Document Reviewer)
Input Type: System Design Documents
Capability Categories: Threat Modeling, Authentication & Authorization, Data Protection, Input Validation & Attack Defense, Infrastructure & Dependencies

---

## T01: IoT Smart Home Hub API

**Difficulty**: Easy
**Category**: Authentication & Authorization Design
**Embedded Problems**: PB-02, PB-07, PB-13

### Input

```markdown
# Smart Home Hub API Design

## Overview
API service for managing IoT devices (lights, thermostats, cameras) through a centralized hub.

## Authentication
- Users register with email/password
- JWT tokens issued on login (24-hour expiration)
- Refresh tokens stored in database for 30 days
- Token storage: localStorage on web client

## API Endpoints

### Device Management
- `POST /api/devices` - Register new device
- `GET /api/devices` - List user's devices
- `PUT /api/devices/{id}` - Update device settings
- `DELETE /api/devices/{id}` - Remove device

### Device Control
- `POST /api/devices/{id}/command` - Send command to device
  - Body: `{"action": "turn_on", "params": {...}}`
  - Commands forwarded directly to device via MQTT

## Data Storage
- PostgreSQL for user accounts and device metadata
- Device telemetry streamed to InfluxDB
- Device images stored in S3 bucket (public-read ACL)

## External Integrations
- Weather API integration for smart thermostat automation
- Email notifications via SendGrid

## Infrastructure
- Kubernetes deployment
- Redis for session caching
- Application secrets in ConfigMaps
```

### Answer Key

**AK-T01-01 (PB-02): JWT Token Storage in localStorage** [Weight: 1.0]
- ○: Identifies XSS vulnerability from localStorage token storage AND recommends httpOnly cookies or secure alternative with XSS risk mitigation
- △: Mentions token storage security issue OR XSS risk but lacks specific secure alternative recommendation
- ×: No mention of token storage vulnerability

**AK-T01-02 (PB-07): Device Command Injection** [Weight: 1.0]
- ○: Identifies lack of input validation on command parameters AND risk of command injection to MQTT devices with specific validation requirements
- △: Mentions need for command validation OR security concern but lacks specificity on injection risk or validation approach
- ×: No mention of command parameter validation

**AK-T01-03 (PB-13): Secrets in ConfigMaps** [Weight: 1.0]
- ○: Identifies ConfigMaps as inappropriate for secrets storage AND recommends Kubernetes Secrets or external secret manager with encryption at rest
- △: Mentions secret management concern OR ConfigMaps issue but lacks specific secure alternative
- ×: No mention of ConfigMaps security issue

**Bonus** (+0.5pt each, max 1.5pt):
- No authorization checks on device endpoints (any authenticated user can control any device)
- S3 bucket with public-read ACL exposes device images
- No rate limiting on command endpoint (DoS risk)

**Penalty** (-0.5pt each):
- Speculating about MQTT broker security without evidence in design
- Recommending specific encryption algorithms without context
- Claiming Redis requires TLS without infrastructure details

### Expected Key Behaviors
- Focus on explicitly described design elements (localStorage, ConfigMaps, command forwarding)
- Identify missing authorization model for device ownership
- Note lack of input validation policy

### Anti-patterns
- Listing generic security practices without tying to specific design issues
- Assuming infrastructure details not mentioned
- Overly detailed recommendations beyond design-level scope

---

## T02: Healthcare Patient Portal

**Difficulty**: Medium
**Category**: Data Protection
**Embedded Problems**: PB-03, PB-08, PB-11, PB-16

### Input

```markdown
# Healthcare Patient Portal Design

## System Purpose
Web portal for patients to view medical records, schedule appointments, and communicate with providers.

## Authentication & Authorization
- OAuth 2.0 with identity provider (Auth0)
- Role-based access: Patient, Provider, Admin
- Session timeout: 30 minutes idle, 8 hours absolute
- Password requirements: 8+ characters, one number

## Data Protection
- Patient records stored in PostgreSQL
- Database backups run daily to S3
- Encryption: TLS 1.2 for data in transit
- Medical images stored in S3 with server-side encryption (SSE-S3)

## Key Features

### Appointment Scheduling
- `POST /api/appointments` - Create appointment
  - Body: `{patient_id, provider_id, datetime, notes}`
- Provider assigns appointment based on specialty matching

### Secure Messaging
- Patients send messages to providers through portal
- Messages stored in database with patient_id and provider_id
- Email notifications sent when new message arrives (includes message preview)

### Document Sharing
- Patients upload documents (insurance cards, referral forms)
- File types: PDF, PNG, JPG (max 10MB)
- Files stored with original filename in S3
- Access: signed URLs valid for 1 hour

## Audit Logging
- Authentication events logged (login, logout, failed attempts)
- Database queries logged to application log files
- Log retention: 30 days

## Infrastructure
- AWS ECS deployment
- RDS PostgreSQL (m5.large instance)
- S3 buckets for backups and file storage
- CloudWatch for monitoring
```

### Answer Key

**AK-T02-01 (PB-03): Weak Password Policy** [Weight: 1.0]
- ○: Identifies insufficient password requirements (only 8 chars + number) for healthcare system AND recommends stronger policy aligned with NIST/HIPAA guidance (complexity, length, common password checks)
- △: Notes password weakness but lacks healthcare context or specific policy recommendations
- ×: No mention of password policy

**AK-T02-02 (PB-08): Insufficient Data Classification** [Weight: 1.0]
- ○: Identifies lack of PII/PHI classification and retention policies required for HIPAA compliance AND recommends data classification framework with retention periods
- △: Mentions missing data classification OR retention but lacks HIPAA compliance context
- ×: No mention of data classification or retention

**AK-T02-03 (PB-11): Sensitive Data in Email Notifications** [Weight: 1.0]
- ○: Identifies message preview in email as PHI leakage risk AND recommends notification without sensitive content (portal link only)
- △: Notes email security concern but doesn't specifically identify preview leakage risk
- ×: No mention of email notification security

**AK-T02-04 (PB-16): Database Backup Encryption** [Weight: 1.0]
- ○: Identifies missing encryption for backups in S3 AND recommends encryption at rest with key management (KMS)
- △: Mentions backup security concern but lacks specificity on encryption requirement
- ×: No mention of backup security

**Bonus** (+0.5pt each, max 2.0pt):
- Missing encryption at rest for RDS database
- Audit logs insufficient for HIPAA (no access logs for PHI)
- File upload lacks content validation (malware/file type verification)
- No mention of BAA (Business Associate Agreement) for third-party services

**Penalty** (-0.5pt each):
- Claiming TLS 1.2 is insufficient without context (it's acceptable if properly configured)
- Recommending specific encryption algorithms without design context
- Speculating about Auth0 vulnerabilities without evidence

### Expected Key Behaviors
- Apply HIPAA compliance lens to healthcare data
- Identify PII/PHI handling gaps in design
- Note missing security controls for sensitive data workflows

### Anti-patterns
- Generic security recommendations without healthcare context
- Overly detailed technical implementation advice
- Assuming infrastructure vulnerabilities not described

---

## T03: E-commerce Order Processing API

**Difficulty**: Medium
**Category**: Input Validation & Attack Defense
**Embedded Problems**: PB-04, PB-09, PB-14, PB-18

### Input

```markdown
# E-commerce Order Processing API Design

## Overview
RESTful API for order management, payment processing, and inventory updates.

## Authentication
- API key authentication for merchant integrations
- JWT tokens for customer web/mobile apps
- API keys passed in custom header: `X-API-Key`

## Order Flow

### Create Order
```
POST /api/orders
{
  "customer_id": 12345,
  "items": [
    {"product_id": "PROD-001", "quantity": 2, "price": 29.99}
  ],
  "shipping_address": {...},
  "discount_code": "SUMMER20"
}
```

- Validate customer_id exists
- Check inventory availability
- Apply discount code if valid
- Calculate total price
- Create order record in PostgreSQL

### Payment Processing
```
POST /api/orders/{order_id}/payment
{
  "payment_method": "credit_card",
  "card_token": "tok_xxxx",
  "amount": 59.98
}
```

- Process payment via Stripe API
- Update order status to "paid"
- Trigger fulfillment workflow

### Order Status
```
GET /api/orders/{order_id}
```
- Returns order details and status
- Response includes customer PII (name, address, phone)

## Inventory Management
- Inventory count updated via background job after order creation
- Redis cache for product availability (TTL: 5 minutes)
- Webhook from warehouse system updates stock levels:
  ```
  POST /api/webhooks/inventory
  {
    "product_id": "PROD-001",
    "quantity": 150,
    "warehouse_id": "WH-01"
  }
  ```

## Rate Limiting
- 100 requests per minute per API key
- Exceeded requests return 429 status

## Infrastructure
- Node.js application on AWS ECS
- PostgreSQL RDS for orders
- Redis ElastiCache for caching
- Stripe API keys stored in environment variables
```

### Answer Key

**AK-T03-01 (PB-04): Price Manipulation Vulnerability** [Weight: 1.0]
- ○: Identifies client-controlled price parameter as tampering risk AND recommends server-side price lookup from product catalog
- △: Notes price validation concern but lacks specificity on tampering risk or solution
- ×: No mention of price parameter security

**AK-T03-02 (PB-09): SQL Injection Risk** [Weight: 1.0]
- ○: Identifies potential SQL injection from customer_id or order_id parameters AND recommends parameterized queries or ORM usage
- △: Mentions SQL injection risk generally but doesn't tie to specific parameters or provide concrete solution
- ×: No mention of SQL injection

**AK-T03-03 (PB-14): Missing Webhook Signature Verification** [Weight: 1.0]
- ○: Identifies lack of authentication/signature verification on inventory webhook AND recommends HMAC signature validation or shared secret
- △: Notes webhook security concern but lacks specificity on signature verification
- ×: No mention of webhook security

**AK-T03-04 (PB-18): Race Condition in Inventory** [Weight: 1.0]
- ○: Identifies background inventory update creating race condition (overselling risk) AND recommends atomic operations or pessimistic locking
- △: Mentions inventory synchronization issue but lacks specificity on race condition or solution
- ×: No mention of inventory concurrency issue

**Bonus** (+0.5pt each, max 2.0pt):
- No CORS policy specified for web/mobile clients
- Missing authorization check on GET /api/orders/{order_id} (IDOR vulnerability)
- API key in custom header lacks standard security practices (prefer Authorization header)
- No input validation on discount code (potential injection or abuse)

**Penalty** (-0.5pt each):
- Claiming Stripe integration is insecure without evidence
- Recommending specific database products without context
- Speculating about Redis security without deployment details

### Expected Key Behaviors
- Identify input validation gaps (price, SQL injection, webhook)
- Note missing authorization on order access
- Recognize tampering risks in order flow

### Anti-patterns
- Generic API security checklist without tying to design
- Assuming implementation details not described
- Overly detailed technical solutions

---

## T04: Corporate VPN Access System

**Difficulty**: Medium
**Category**: Threat Modeling (STRIDE)
**Embedded Problems**: PB-01, PB-10, PB-15, PB-19

### Input

```markdown
# Corporate VPN Access Management System

## System Purpose
Manage employee VPN access, authenticate users, and enforce network access policies.

## Authentication Flow

### Initial Setup
1. Employee registers with corporate email
2. System validates email domain (@company.com)
3. MFA enrollment: TOTP app or SMS
4. Account activated after email verification

### VPN Connection
1. Client initiates VPN connection request
2. User enters username and password
3. If credentials valid, MFA challenge sent
4. Upon successful MFA, VPN session established (8-hour duration)
5. Session token stored in client configuration file

## Authorization Model
- Role-based access to internal network segments
- Roles: Employee, Contractor, Admin
- Network segments: General, Engineering, Finance, HR
- Access rules:
  - Employee: General + Engineering
  - Contractor: General only
  - Admin: All segments

## Audit & Monitoring

### Connection Logs
- Timestamp of connection/disconnection
- Username and source IP
- Network segment accessed
- Logs stored in Elasticsearch cluster

### Failed Authentication
- Failed login attempts logged
- Account locked after 5 failures (24-hour lockout)

## Infrastructure
- OpenVPN server on EC2 instances
- User directory in MySQL database
- Session tokens cached in Memcached
- Certificate authority for client certificates (self-signed root CA)

## Backup & Recovery
- MySQL backups to EBS snapshots (weekly)
- VPN server config backed up to S3
- Recovery procedure documented in wiki
```

### Answer Key

**AK-T04-01 (PB-01): SMS-based MFA Vulnerability** [Weight: 1.0]
- ○: Identifies SMS as weak MFA method (SIM swap, interception risks) AND recommends hardware token, push notification, or WebAuthn
- △: Notes MFA security concern but lacks specificity on SMS risks or stronger alternatives
- ×: No mention of MFA method security

**AK-T04-02 (PB-10): Insufficient Audit Logging** [Weight: 1.0]
- ○: Identifies missing audit events (role changes, policy modifications, MFA resets) critical for security monitoring AND recommends comprehensive audit logging for privileged operations
- △: Notes incomplete logging but lacks specificity on missing critical events
- ×: No mention of audit logging gaps

**AK-T04-03 (PB-15): Session Token in Configuration File** [Weight: 1.0]
- ○: Identifies session token storage in config file as credential exposure risk AND recommends secure storage (OS keychain, encrypted credential store)
- △: Mentions token storage concern but lacks specificity on exposure risk or secure alternative
- ×: No mention of token storage security

**AK-T04-04 (PB-19): Self-signed Certificate Authority** [Weight: 1.0]
- ○: Identifies self-signed CA as trust and key management risk AND recommends enterprise CA or managed PKI service with proper key protection
- △: Notes certificate security concern but lacks specificity on self-signed risks
- ×: No mention of CA security

**Bonus** (+0.5pt each, max 2.0pt):
- Missing revocation mechanism for VPN access (employee termination)
- No encryption at rest for MySQL user directory
- Source IP logging insufficient for geolocation-based anomaly detection
- Account lockout lacks notification or admin override mechanism

**Penalty** (-0.5pt each):
- Claiming OpenVPN is inherently insecure without design-specific issues
- Recommending specific products without context
- Speculating about network security without infrastructure details

### Expected Key Behaviors
- Apply STRIDE threat model to VPN authentication flow
- Identify authentication bypass risks (SMS MFA, token storage)
- Note missing audit capabilities for security operations

### Anti-patterns
- Generic VPN security checklist
- Assuming vulnerabilities not present in design
- Overly detailed infrastructure recommendations

---

## T05: Financial Trading Platform

**Difficulty**: Hard
**Category**: Authentication & Authorization Design
**Embedded Problems**: PB-05, PB-06, PB-12, PB-17, PB-20

### Input

```markdown
# Financial Trading Platform Design

## Overview
Real-time stock trading platform for retail investors with order execution, portfolio management, and market data streaming.

## Authentication

### User Registration
- Email/password signup
- Password requirements: 12+ characters, mixed case, numbers, symbols
- Email verification required
- Optional MFA enrollment (TOTP)

### Session Management
- Access token (JWT, 15-minute expiration)
- Refresh token (opaque, 7-day expiration)
- Token refresh endpoint: `POST /api/auth/refresh`
  - Accepts refresh token
  - Issues new access token
  - Old refresh token remains valid until expiration

### Account Recovery
- Password reset via email link
- Reset link valid for 1 hour
- User clicks link, enters new password
- Password updated, all sessions invalidated

## Trading Operations

### Place Order
```
POST /api/orders
Authorization: Bearer {access_token}
{
  "account_id": "ACC-12345",
  "symbol": "AAPL",
  "order_type": "market",
  "quantity": 100,
  "side": "buy"
}
```

- Validate account_id belongs to authenticated user
- Check account balance sufficiency
- Submit order to exchange API
- Return order confirmation

### Cancel Order
```
DELETE /api/orders/{order_id}
Authorization: Bearer {access_token}
```

- Cancel order if status is "pending"
- No verification of order ownership

## Market Data Streaming
- WebSocket connection for real-time quotes
- Connection established with access token
- No re-authentication for long-lived connections (hours)
- Rate limit: 100 symbols per connection

## Account Management

### Withdraw Funds
```
POST /api/accounts/{account_id}/withdraw
{
  "amount": 5000.00,
  "bank_account": "****1234"
}
```

- Verify account ownership
- Require additional authentication: password re-entry
- Process withdrawal via banking API (Plaid)

### Transaction History
```
GET /api/accounts/{account_id}/transactions
```
- Returns all transactions for account
- No pagination (potentially thousands of records)

## Audit & Compliance
- Trade execution logs stored in Aurora PostgreSQL
- User activity logs sent to CloudWatch
- Regulatory reporting: daily batch job exports trades to FINRA format
- Log retention: 7 years

## Infrastructure
- EKS cluster (3 availability zones)
- PostgreSQL RDS for user accounts and orders
- DynamoDB for real-time order book
- Redis for session caching and rate limiting
- Third-party services: Plaid (banking), Alpaca (market data)
```

### Answer Key

**AK-T05-01 (PB-05): Refresh Token Not Rotated** [Weight: 1.0]
- ○: Identifies lack of refresh token rotation as token theft risk AND recommends one-time-use tokens with rotation on each refresh
- △: Notes refresh token security concern but lacks specificity on rotation requirement
- ×: No mention of refresh token rotation

**AK-T05-02 (PB-06): Missing Step-up Authentication** [Weight: 1.0]
- ○: Identifies inconsistent re-authentication (present for withdrawal but missing for high-risk operations like large trades or account changes) AND recommends consistent step-up auth policy
- △: Notes authentication concern but lacks specificity on step-up requirement or inconsistency
- ×: No mention of step-up authentication

**AK-T05-03 (PB-12): Insecure Authorization on Cancel Order** [Weight: 1.0]
- ○: Identifies missing order ownership verification on DELETE endpoint AND recommends authorization check before cancellation (IDOR vulnerability)
- △: Notes authorization concern but lacks specificity on order ownership check
- ×: No mention of cancel order authorization

**AK-T05-04 (PB-17): WebSocket Re-authentication Gap** [Weight: 1.0]
- ○: Identifies lack of periodic re-authentication on long-lived WebSocket connections as session hijacking risk AND recommends periodic token refresh or connection time limits
- △: Notes WebSocket security concern but lacks specificity on re-authentication requirement
- ×: No mention of WebSocket authentication

**AK-T05-05 (PB-20): No Pagination on Transaction History** [Weight: 1.0]
- ○: Identifies missing pagination as DoS risk (memory exhaustion, slow queries) AND recommends pagination with reasonable limits
- △: Notes transaction query concern but lacks specificity on DoS risk or pagination
- ×: No mention of transaction query issues

**Bonus** (+0.5pt each, max 2.5pt):
- Missing rate limiting on order placement (market manipulation risk)
- No fraud detection or anomaly detection system mentioned
- Password reset invalidates sessions but doesn't revoke refresh tokens
- MFA optional for financial platform (should be mandatory)
- No mention of encryption at rest for sensitive financial data

**Penalty** (-0.5pt each):
- Claiming Plaid or Alpaca integration is insecure without evidence
- Recommending specific fraud detection algorithms without design context
- Speculating about database security without deployment details

### Expected Key Behaviors
- Apply financial security standards to authentication flow
- Identify authorization gaps across multiple endpoints
- Recognize session management weaknesses (token rotation, re-auth)
- Note DoS and resource exhaustion risks

### Anti-patterns
- Generic fintech security checklist
- Assuming infrastructure vulnerabilities not described
- Overly detailed trading logic recommendations

---

## T06: SaaS Admin Dashboard

**Difficulty**: Easy
**Category**: Infrastructure & Dependencies
**Embedded Problems**: PB-21, PB-22, PB-23

### Input

```markdown
# SaaS Admin Dashboard Design

## Overview
Internal admin dashboard for managing customer accounts, viewing analytics, and performing support operations.

## Authentication
- SSO with Google Workspace (OAuth 2.0)
- Admin accounts tied to @company.com email domain
- Session expires after 30 minutes idle

## Admin Operations

### Customer Account Management
- `GET /admin/customers` - List all customer accounts
- `GET /admin/customers/{id}` - View customer details (PII, subscription, usage)
- `POST /admin/customers/{id}/impersonate` - Login as customer for support
- `PUT /admin/customers/{id}/subscription` - Modify subscription plan

### System Monitoring
- Dashboard displays real-time metrics (API latency, error rates, active users)
- Metrics sourced from Prometheus
- Alerts configured in PagerDuty

### Database Access
- Admins can execute read-only SQL queries via web interface for troubleshooting
- Query input: free-form text field
- Results displayed in table format
- Queries logged to application log

## Infrastructure
- React frontend hosted on S3 + CloudFront
- Node.js backend on ECS
- PostgreSQL RDS for customer data
- Dependency: Lodash 4.17.0, Moment.js, Axios
- npm install run during Docker build
- Environment variables in .env file committed to git repository

## CI/CD
- GitHub Actions workflow builds Docker image
- Pushes to ECR on merge to main branch
- ECS service updated with new image
```

### Answer Key

**AK-T06-01 (PB-21): Vulnerable Dependencies** [Weight: 1.0]
- ○: Identifies outdated dependency (Lodash 4.17.0 has known vulnerabilities) AND recommends dependency scanning, version updates, and automated vulnerability monitoring
- △: Notes dependency security concern but lacks specificity on vulnerability risk or scanning process
- ×: No mention of dependency vulnerabilities

**AK-T06-02 (PB-22): Secrets in Git Repository** [Weight: 1.0]
- ○: Identifies .env file committed to git as credential exposure risk AND recommends secret manager (AWS Secrets Manager, Vault) with git history cleanup
- △: Notes secret management concern but lacks specificity on git exposure or secure alternative
- ×: No mention of secrets in git

**AK-T06-03 (PB-23): SQL Injection in Query Interface** [Weight: 1.0]
- ○: Identifies free-form SQL input as injection risk even for read-only queries (data exfiltration, system table access) AND recommends parameterized query builder or pre-defined query templates
- △: Notes SQL query security concern but lacks specificity on injection risk despite read-only context
- ×: No mention of SQL query interface security

**Bonus** (+0.5pt each, max 1.5pt):
- Customer impersonation lacks audit trail or approval workflow
- No authorization granularity (all admins have full access)
- Missing Content Security Policy for React frontend

**Penalty** (-0.5pt each):
- Claiming OAuth 2.0 SSO is inherently insecure without design-specific issues
- Recommending specific dependency versions without vulnerability context
- Speculating about CI/CD pipeline security without evidence

### Expected Key Behaviors
- Focus on supply chain security (dependencies, secrets)
- Identify admin privilege risks (impersonation, SQL access)
- Note missing audit controls for high-privilege operations

### Anti-patterns
- Generic admin panel security checklist
- Assuming frontend vulnerabilities not described
- Overly detailed infrastructure recommendations

---

## T07: Real-time Collaboration Platform

**Difficulty**: Hard
**Category**: Input Validation & Attack Defense
**Embedded Problems**: PB-24, PB-25, PB-26, PB-27, PB-28

### Input

```markdown
# Real-time Collaboration Platform Design

## Overview
Document collaboration platform with real-time editing, comments, and sharing (similar to Google Docs).

## Authentication & Authorization
- Email/password or social login (Google, GitHub)
- JWT access tokens (1-hour expiration)
- Document access control:
  - Owner: full permissions
  - Editor: can edit content and invite others
  - Viewer: read-only
  - Public link: anyone with link can view

## Document Management

### Create Document
```
POST /api/documents
{
  "title": "Meeting Notes",
  "content": "<p>Initial content</p>",
  "visibility": "private"
}
```

### Share Document
```
POST /api/documents/{doc_id}/share
{
  "email": "user@example.com",
  "permission": "editor"
}
```
- System sends email invitation
- Email contains direct document URL with access token in query parameter
- Token grants access without login

### Edit Document
```
PATCH /api/documents/{doc_id}
{
  "content": "<p>Updated content with <script>alert('xss')</script></p>"
}
```
- Content stored as HTML in PostgreSQL
- Real-time sync via WebSocket broadcasts content to all connected clients
- Content rendered directly in browser without sanitization

### Export Document
```
GET /api/documents/{doc_id}/export?format=pdf
```
- Server-side rendering with Puppeteer
- HTML content converted to PDF
- File served with original document title as filename: `Content-Disposition: attachment; filename="{title}.pdf"`

## Comments & Mentions
- Users can comment on document sections
- @ mentions notify users: `@john.doe check this out`
- Mention triggers webhook to notification service:
  ```
  POST https://notifications.internal/webhook
  {
    "mentioned_user": "john.doe",
    "document_id": "doc-123",
    "comment": "User input with @john.doe"
  }
  ```

## Search
- Full-text search across documents
- Query: `GET /api/search?q={user_input}`
- Search implemented with raw SQL: `SELECT * FROM documents WHERE content LIKE '%{q}%'`

## File Attachments
- Users can attach files to documents
- Supported types: PDF, images, Office docs
- Files uploaded to: `POST /api/documents/{doc_id}/attachments`
- Files stored in S3 with keys: `attachments/{doc_id}/{original_filename}`
- File URLs returned to client: `https://bucket.s3.amazonaws.com/attachments/doc-123/file.pdf`

## Infrastructure
- Node.js backend on Kubernetes
- PostgreSQL for documents and user data
- Redis Pub/Sub for real-time sync
- S3 for file storage
- Rate limiting: 1000 requests per hour per user
```

### Answer Key

**AK-T07-01 (PB-24): Stored XSS Vulnerability** [Weight: 1.0]
- ○: Identifies unsanitized HTML storage and rendering as XSS risk AND recommends input sanitization (DOMPurify) or CSP with output escaping
- △: Notes XSS concern but lacks specificity on stored XSS risk or sanitization approach
- ×: No mention of XSS vulnerability

**AK-T07-02 (PB-25): SSRF in Export Function** [Weight: 1.0]
- ○: Identifies Puppeteer rendering user content as SSRF risk (malicious HTML with external resource fetches) AND recommends sandboxing or content validation
- △: Notes export security concern but lacks specificity on SSRF risk
- ×: No mention of export function security

**AK-T07-03 (PB-26): SQL Injection in Search** [Weight: 1.0]
- ○: Identifies raw SQL string concatenation in search as SQL injection risk AND recommends parameterized queries or ORM
- △: Notes search security concern but lacks specificity on SQL injection or solution
- ×: No mention of search function security

**AK-T07-04 (PB-27): Path Traversal in File Storage** [Weight: 1.0]
- ○: Identifies use of original filename in S3 key as path traversal risk (e.g., `../../sensitive.txt`) AND recommends UUID-based keys or filename sanitization
- △: Notes file storage concern but lacks specificity on path traversal or solution
- ×: No mention of file storage security

**AK-T07-05 (PB-28): Command Injection in Webhook** [Weight: 1.0]
- ○: Identifies unvalidated user input in webhook payload as command injection risk (if notification service processes input unsafely) AND recommends input validation or structured format
- △: Notes webhook security concern but lacks specificity on injection risk
- ×: No mention of webhook security

**Bonus** (+0.5pt each, max 2.5pt):
- Access token in URL query parameter (sharing link) exposes token in logs/referrer headers
- Missing CSRF protection on document operations
- No file content validation (malware upload risk)
- Direct S3 URL exposure allows bucket enumeration
- Header injection risk in Content-Disposition filename

**Penalty** (-0.5pt each):
- Claiming rate limiting is insufficient without context
- Recommending specific libraries without design-level justification
- Speculating about Redis Pub/Sub security without deployment details

### Expected Key Behaviors
- Identify multiple injection vulnerabilities (XSS, SQL, command, path traversal)
- Recognize SSRF risk in server-side rendering
- Note cascading security issues (token in URL, unvalidated webhooks)

### Anti-patterns
- Generic web security checklist
- Assuming all possible injection types without design evidence
- Overly detailed implementation-level fixes

---

## T08: Multi-tenant SaaS Analytics Platform

**Difficulty**: Hard
**Category**: Data Protection
**Embedded Problems**: PB-29, PB-30, PB-31, PB-32, PB-33

### Input

```markdown
# Multi-tenant SaaS Analytics Platform Design

## Overview
Analytics platform where customers (tenants) ingest event data, run queries, and build dashboards.

## Tenant Isolation

### Data Model
- All tenant data stored in shared PostgreSQL database
- Table structure:
  ```
  events (
    id UUID PRIMARY KEY,
    tenant_id UUID,
    event_type VARCHAR,
    event_data JSONB,
    timestamp TIMESTAMP
  )
  ```
- Queries filter by tenant_id: `SELECT * FROM events WHERE tenant_id = '{current_tenant}'`

### Query Execution
- Customers write custom SQL queries via dashboard
- Query endpoint:
  ```
  POST /api/query
  {
    "sql": "SELECT event_type, COUNT(*) FROM events WHERE timestamp > '2024-01-01' GROUP BY event_type"
  }
  ```
- Backend prepends tenant filter: `SELECT ... FROM events WHERE tenant_id = '{tenant_id}' AND (...)`
- Query executed with single database user account

## Data Ingestion

### Event API
```
POST /api/events
Authorization: Bearer {api_key}
{
  "event_type": "page_view",
  "user_id": "user-123",
  "properties": {
    "page": "/home",
    "referrer": "https://google.com"
  }
}
```
- API key identifies tenant
- Events written to database immediately
- No PII detection or masking

### Bulk Import
- Customers upload CSV files via web interface
- Files processed asynchronously by worker jobs
- Original files stored in S3 bucket (shared across tenants): `s3://analytics-data/uploads/{filename}`

## Dashboards
- Pre-built dashboards with embedded queries
- Dashboard configuration stored as JSON with raw SQL:
  ```
  {
    "widgets": [
      {
        "query": "SELECT * FROM events WHERE event_type = 'purchase'"
      }
    ]
  }
  ```
- Dashboards can be exported and imported between tenants

## Audit & Compliance
- Customer data retention: indefinite (no automatic deletion)
- Logs: application logs only (no data access audit)
- GDPR deletion requests: manual SQL execution by ops team

## Infrastructure
- Kubernetes on GCP
- Cloud SQL PostgreSQL (single instance, db-n1-standard-4)
- Cloud Storage for CSV uploads
- Redis for caching query results (no TTL, shared instance)
```

### Answer Key

**AK-T08-01 (PB-29): Weak Tenant Isolation** [Weight: 1.0]
- ○: Identifies SQL string concatenation for tenant filtering as tenant data leakage risk (SQL injection can bypass tenant_id filter) AND recommends database-level isolation (RLS policies, separate schemas) or parameterized queries with defense-in-depth
- △: Notes tenant isolation concern but lacks specificity on SQL injection bypass risk or architectural solution
- ×: No mention of tenant isolation security

**AK-T08-02 (PB-30): Shared Database Credentials** [Weight: 1.0]
- ○: Identifies single database user for all queries as privilege escalation and isolation risk AND recommends per-tenant database roles or connection pooling with tenant-specific credentials
- △: Notes database access concern but lacks specificity on shared credential risk
- ×: No mention of database credential model

**AK-T08-03 (PB-31): Missing PII Detection and Masking** [Weight: 1.0]
- ○: Identifies lack of PII detection/masking as privacy compliance risk (GDPR, CCPA) AND recommends automated PII scanning with masking or tokenization policies
- △: Notes PII handling concern but lacks specificity on detection/masking requirement
- ×: No mention of PII handling

**AK-T08-04 (PB-32): Insecure File Storage** [Weight: 1.0]
- ○: Identifies shared S3 bucket with predictable filenames as cross-tenant file access risk AND recommends tenant-specific prefixes or separate buckets with IAM policies
- △: Notes file storage concern but lacks specificity on cross-tenant access risk
- ×: No mention of file storage security

**AK-T08-05 (PB-33): Shared Redis Cache Without Tenant Isolation** [Weight: 1.0]
- ○: Identifies shared Redis instance without tenant key namespacing as cache poisoning/data leakage risk AND recommends tenant-prefixed keys or separate cache instances
- △: Notes cache security concern but lacks specificity on tenant isolation in cache
- ×: No mention of cache security

**Bonus** (+0.5pt each, max 2.5pt):
- No audit logging for data access (GDPR compliance gap)
- Missing data retention policies and automatic deletion
- Dashboard import/export could leak SQL patterns or data insights across tenants
- No query resource limits (DoS risk from expensive queries)
- Manual GDPR deletion process error-prone and unauditable

**Penalty** (-0.5pt each):
- Claiming PostgreSQL is unsuitable for multi-tenancy without design-specific issues
- Recommending complete database redesign without recognizing partial mitigations
- Speculating about GCP security without evidence

### Expected Key Behaviors
- Focus on multi-tenant isolation failures across data, storage, cache
- Identify privilege escalation risks (shared DB credentials, SQL injection)
- Recognize compliance gaps (PII, GDPR, audit)

### Anti-patterns
- Generic multi-tenancy checklist
- Assuming all possible isolation failures without design evidence
- Overly prescriptive architectural recommendations
