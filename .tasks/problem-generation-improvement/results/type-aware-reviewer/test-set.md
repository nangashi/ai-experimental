# Test Scenario Set: security-design-reviewer

## Agent Information
- **Agent Name**: security-design-reviewer
- **Agent Type**: Type-A (Document Reviewer)
- **Input Type**: Design documents, architecture documents, system specifications
- **Capability Categories**: Threat Modeling (STRIDE), Authentication & Authorization Design, Data Protection, Input Validation & Attack Defense, Infrastructure/Dependencies/Audit

---

### T01: Multi-Tenant SaaS Analytics Platform

**Difficulty**: Medium
**Category**: Authentication & Authorization Design, Data Protection

#### Input

```markdown
# Analytics Platform Design

## Overview
Multi-tenant SaaS analytics platform for business intelligence. Each organization has isolated data workspace with role-based access.

## Architecture
- Frontend: React SPA
- Backend: Node.js REST API
- Database: PostgreSQL with shared schema
- Storage: S3 for report exports
- Cache: Redis for session data

## Authentication Flow
Users authenticate via email/password. JWT token issued with 24-hour expiration. Token contains userId, organizationId, and role.

## Authorization Model
Three roles: Admin, Analyst, Viewer
- Admin: Full access to org data and user management
- Analyst: Read/write access to reports and dashboards
- Viewer: Read-only access to dashboards

API endpoints validate JWT and check role from token payload.

## Data Model
Organizations table with orgId as primary key. Users belong to one organization. Reports and dashboards have orgId foreign key.

Query pattern: `SELECT * FROM reports WHERE orgId = ?` where orgId comes from JWT token.

## Report Export
Users can export reports to PDF/CSV. Export job queued in Redis, processed by worker nodes, uploaded to S3 with path: `s3://bucket/exports/{orgId}/{reportId}.pdf`

Workers fetch job from queue, query database, generate file, upload to S3, send email with download link valid for 7 days.

## Sensitive Data
Customer PII includes email, phone, company name. Financial metrics stored as numeric values. No encryption specified for database or S3 storage.
```

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T01-C1 | Tenant Isolation Vulnerability | Identifies SQL injection or token manipulation risk allowing cross-tenant data access | Mentions need for better authorization but misses specific attack vector | Does not identify tenant isolation as security issue | 1.0 |
| T01-C2 | JWT Token Security | Identifies insecure JWT storage, lack of refresh token mechanism, and long expiration risk | Mentions one JWT security concern (storage OR expiration OR refresh) | Does not identify JWT security issues | 1.0 |
| T01-C3 | Data Protection at Rest | Identifies lack of encryption for PII in PostgreSQL and S3, with specific recommendations | Mentions need for encryption but lacks specificity on which data stores | Does not identify encryption requirements | 1.0 |
| T01-C4 | Export URL Security | Identifies risk of predictable S3 paths and lack of signed URLs/access controls | Mentions S3 security generically without URL-specific issues | Does not identify export access control issues | 1.0 |
| T01-C5 | Session Management | Identifies Redis session security issues (encryption, timeout, invalidation) | Mentions one session security concern | Does not identify session management issues | 0.5 |

#### Expected Key Behaviors
- Identify tenant isolation vulnerability through SQL injection or JWT manipulation
- Point out lack of database and S3 encryption for PII
- Recognize JWT security issues (storage, expiration, refresh mechanism)
- Identify predictable S3 export paths as information disclosure risk
- Suggest defense-in-depth for authorization (database-level checks, not just JWT)

#### Anti-patterns
- Focus only on generic security recommendations without analyzing specific design flaws
- Miss the core tenant isolation vulnerability
- Overlook data protection gaps for PII
- Fail to connect JWT payload trust to authorization bypass risk

---

### T02: Healthcare Appointment Booking API

**Difficulty**: Hard
**Category**: Threat Modeling (STRIDE), Input Validation & Attack Defense

#### Input

```markdown
# Healthcare Appointment Booking System

## System Components
- Public API: Spring Boot REST API
- Database: MySQL for appointments, patients, doctors
- Message Queue: RabbitMQ for notifications
- External Integration: SMS gateway, Email service, Insurance verification API

## API Endpoints

### POST /api/appointments
Creates new appointment. Request body:
```json
{
  "patientId": "string",
  "doctorId": "string",
  "datetime": "ISO8601",
  "duration": "integer (minutes)",
  "reason": "string",
  "insuranceProvider": "string"
}
```

Validation: All fields required. Datetime must be future. Duration between 15-120 minutes.

Process:
1. Validate input fields
2. Check doctor availability in database
3. Call insurance API to verify coverage
4. Create appointment record
5. Queue notification messages (SMS + Email)
6. Return appointment ID

### DELETE /api/appointments/{id}
Cancels appointment. Requires authentication header with patient JWT token.

Checks if appointment belongs to authenticated patient by comparing patientId in appointment record with patientId in JWT. If match, deletes appointment and sends cancellation notification.

## Input Handling
Reason field stored as-is in database for doctor review. Insurance provider name used in API query parameter: `https://insurance-api.com/verify?provider={insuranceProvider}`

Patient and doctor IDs are UUIDs validated with regex pattern.

## Error Handling
Validation errors return 400 with error message. Insurance API failures return 500 with "Insurance verification failed" message. Database errors logged but return generic "Internal server error".

## Rate Limiting
None specified.
```

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T02-C1 | SQL Injection via Reason Field | Identifies SQL injection risk in unescaped reason field with specific attack scenario | Mentions input validation need without identifying SQL injection specifically | Does not identify SQL injection vulnerability | 1.0 |
| T02-C2 | SSRF in Insurance API Call | Identifies SSRF vulnerability in unvalidated insurance provider parameter | Mentions API security without identifying SSRF specifically | Does not identify SSRF risk | 1.0 |
| T02-C3 | DoS/Resource Exhaustion | Identifies lack of rate limiting and queue flooding risk through appointment spam | Mentions need for rate limiting without attack scenario | Does not identify DoS vulnerability | 1.0 |
| T02-C4 | Authorization Bypass in DELETE | Identifies IDOR vulnerability where patientId from JWT can be manipulated to cancel others' appointments | Mentions authorization concern without specific bypass mechanism | Does not identify authorization vulnerability | 1.0 |
| T02-C5 | Information Disclosure in Errors | Identifies security risk of detailed error messages revealing system internals | Mentions error handling without security implications | Does not identify information disclosure | 0.5 |
| T02-C6 | Message Queue Security | Identifies lack of authentication/encryption for RabbitMQ notifications containing PII | Mentions notification security generically | Does not identify message queue security | 0.5 |

#### Expected Key Behaviors
- Apply STRIDE framework systematically (Spoofing in auth, Tampering in SQL injection, Repudiation in audit logging, Information Disclosure in errors, DoS in rate limiting, Elevation in authorization)
- Identify injection vulnerabilities (SQL in reason field, SSRF in insurance parameter)
- Recognize authorization bypass through JWT manipulation
- Assess DoS risk from unlimited appointment creation
- Consider data flow security (PII in message queue)

#### Anti-patterns
- Generic security checklist without analyzing actual design flaws
- Miss critical injection vulnerabilities
- Focus only on authentication without examining authorization logic
- Overlook cascading effects (spam appointments → queue flooding)

---

### T03: Content Management System with File Upload

**Difficulty**: Easy
**Category**: Input Validation & Attack Defense

#### Input

```markdown
# CMS File Upload Feature Design

## Feature Overview
Allow content editors to upload images, documents, and media files for articles.

## Upload Flow
1. User selects file from browser
2. JavaScript validates file size < 10MB
3. POST to `/api/upload` with multipart/form-data
4. Server validates file extension against whitelist: [jpg, png, gif, pdf, docx, mp4]
5. File saved to `/var/www/uploads/{filename}`
6. Database record created with file path
7. Return public URL: `https://cdn.example.com/uploads/{filename}`

## File Serving
Nginx serves files directly from `/var/www/uploads/` directory. No authentication required for file access. Files served with original filename and auto-detected Content-Type.

## File Processing
PDF files automatically converted to images for preview. Conversion uses ImageMagick convert command: `convert {filepath} {outputpath}`

## Storage Limits
Each user has 1GB quota. Total storage tracked in database.
```

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T03-C1 | File Extension Bypass | Identifies risk of extension bypass (double extensions, MIME type mismatch, case sensitivity) and recommends magic byte validation | Mentions need for better file validation without specific bypass techniques | Does not identify file validation vulnerabilities | 1.0 |
| T03-C2 | Path Traversal | Identifies path traversal risk in filename handling and recommends sanitization/random naming | Mentions filename security without specific attack vector | Does not identify path traversal vulnerability | 1.0 |
| T03-C3 | Command Injection in ImageMagick | Identifies command injection risk in convert command and recommends input sanitization or safe alternatives | Mentions processing security generically | Does not identify command injection | 1.0 |
| T03-C4 | Unrestricted File Access | Identifies information disclosure risk from public file access and recommends access controls | Mentions need for authentication without specific impact | Does not identify access control issue | 0.5 |
| T03-C5 | XSS via Content-Type | Identifies XSS risk from auto-detected Content-Type serving HTML/SVG with scripts | Mentions Content-Type security without XSS scenario | Does not identify XSS vulnerability | 1.0 |

#### Expected Key Behaviors
- Identify multiple file upload attack vectors (extension bypass, path traversal, command injection)
- Recognize command injection in ImageMagick convert
- Point out XSS risk from serving user-uploaded content with auto-detected MIME types
- Suggest defense-in-depth (extension + MIME validation, random filenames, sandboxed processing)
- Identify lack of access controls for uploaded files

#### Anti-patterns
- Only mention generic "validate file uploads" without specific vulnerabilities
- Miss command injection in file processing
- Focus on file size limits without security implications
- Overlook XSS risk in file serving

---

### T04: Microservices E-Commerce Platform

**Difficulty**: Hard
**Category**: Infrastructure, Dependencies & Audit, Authentication & Authorization Design

#### Input

```markdown
# E-Commerce Platform - Microservices Architecture

## Services
1. **User Service**: Authentication, user profiles (Node.js)
2. **Product Service**: Catalog, inventory (Java Spring)
3. **Order Service**: Order management, payment processing (Python Flask)
4. **Notification Service**: Email, SMS notifications (Node.js)

## Service Communication
Services communicate via HTTP REST APIs. Internal service network on Docker bridge network.

User Service issues JWT tokens for external clients. Internal service-to-service calls use API keys stored in environment variables.

Example: Order Service calls Product Service with header `X-API-Key: prod_service_key_12345`

## Secrets Management
- Database credentials in docker-compose.yml
- Third-party API keys (Stripe, SendGrid) in .env files
- JWT signing secret: hardcoded in User Service code as `const SECRET = "my-jwt-secret-2023"`

## Infrastructure
- Deployment: Docker Compose on single EC2 instance
- Database: Single PostgreSQL instance shared by all services
- Reverse Proxy: Nginx routes external traffic to services
- Logging: Console output captured by Docker logs

## Dependencies
Services use various npm/pip/maven packages. No automated dependency scanning. Manual updates quarterly.

## Monitoring
CloudWatch monitors EC2 CPU and memory. No application-level security monitoring. Failed login attempts logged to console.
```

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T04-C1 | Hardcoded Secrets | Identifies multiple secret leakage risks (hardcoded JWT secret, env file commits, docker-compose credentials) with specific remediation using secrets management tools | Mentions need for secrets management without identifying all exposure points | Does not identify secret management issues | 1.0 |
| T04-C2 | Weak Service-to-Service Auth | Identifies inadequate API key authentication for internal services and recommends mutual TLS or service mesh | Mentions need for better internal auth without specific recommendations | Does not identify internal auth weakness | 1.0 |
| T04-C3 | Shared Database Security | Identifies security risks of shared database (privilege escalation, lack of isolation) and recommends dedicated databases or strict access controls | Mentions database security generically | Does not identify shared database risks | 1.0 |
| T04-C4 | Dependency Vulnerabilities | Identifies lack of vulnerability scanning and automated updates for third-party libraries with specific tools (Dependabot, Snyk) | Mentions dependency management without security implications | Does not identify dependency vulnerability risk | 1.0 |
| T04-C5 | Security Audit Logging | Identifies insufficient audit logging (no centralized logs, no security event monitoring, console-only logging) with recommendations | Mentions logging improvement without security focus | Does not identify audit logging gaps | 0.5 |
| T04-C6 | Network Segmentation | Identifies lack of network isolation between services and external attack surface | Mentions network security generically | Does not identify network segmentation issues | 0.5 |

#### Expected Key Behaviors
- Systematically assess infrastructure security (secrets, network, dependencies, monitoring)
- Identify secret management failures across multiple components
- Recognize inadequate service-to-service authentication
- Point out lack of security audit capabilities
- Recommend specific tools and practices (Vault, mTLS, SIEM, dependency scanning)
- Connect infrastructure weaknesses to potential attack scenarios

#### Anti-patterns
- Generic infrastructure recommendations without analyzing specific design flaws
- Miss hardcoded secrets
- Focus only on external-facing security without internal service security
- Overlook dependency management and audit logging gaps

---

### T05: Mobile Banking App Backend

**Difficulty**: Medium
**Category**: Authentication & Authorization Design, Threat Modeling (STRIDE)

#### Input

```markdown
# Mobile Banking Backend API Design

## Authentication
Users register with email, password (min 8 chars), and 6-digit PIN. Passwords hashed with bcrypt (cost 10). PIN stored as MD5 hash.

Login flow:
1. POST /auth/login with email + password
2. Returns access token (JWT, 30 min exp) and refresh token (UUID, 30 day exp)
3. Refresh tokens stored in database with userId

Token refresh: POST /auth/refresh with refresh token in body, returns new access token.

PIN verification: Required for sensitive operations (transfers, settings changes). Submitted as plain text in request body, compared against MD5 hash.

## Biometric Authentication
App supports fingerprint/Face ID. After successful biometric auth, app uses stored access token. If expired, app automatically calls /auth/refresh with stored refresh token.

Biometric credentials stored on device only. No server-side biometric data.

## Authorization
Account access validated by matching accountId in JWT with accountId in request path. Example: GET /accounts/{accountId}/transactions

Transaction creation (POST /transactions) validates:
- Source accountId matches JWT
- Sufficient balance
- Daily limit not exceeded

## Password Reset
User requests reset via email. System generates 6-digit numeric code, expires in 15 minutes. Code sent via email. User submits email + code + new password to /auth/reset endpoint.

Reset endpoint validates code, updates password, and invalidates all existing refresh tokens for that user.

## Session Management
No server-side session store. JWT tokens stateless. Access token invalidation not supported. Refresh token can be revoked by deleting from database.
```

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T05-C1 | Weak PIN Security | Identifies MD5 vulnerability for PIN storage and plain text PIN transmission | Mentions need for better PIN handling without identifying both storage and transmission issues | Does not identify PIN security weaknesses | 1.0 |
| T05-C2 | Token Storage and Replay Risk | Identifies risks of client-side token storage without guidance on secure storage mechanisms (Keychain/Keystore) | Mentions token security generically | Does not identify token storage issues | 1.0 |
| T05-C3 | Password Reset Security | Identifies weak reset code (6-digit numeric = 1M possibilities) and lack of rate limiting enabling brute force | Mentions one reset security issue (code weakness OR rate limiting) | Does not identify password reset vulnerabilities | 1.0 |
| T05-C4 | Lack of Access Token Revocation | Identifies inability to invalidate compromised access tokens and recommends token blacklisting or shorter expiration | Mentions token management without revocation-specific issue | Does not identify token revocation gap | 1.0 |
| T05-C5 | Authorization Logic Vulnerabilities | Identifies IDOR risk in accountId validation and recommends user-account relationship verification | Mentions authorization without specific bypass scenario | Does not identify authorization vulnerabilities | 0.5 |

#### Expected Key Behaviors
- Apply STRIDE to authentication mechanisms (Spoofing via weak PIN, Repudiation via stateless tokens, Elevation via IDOR)
- Identify cryptographic weaknesses (MD5 for PIN)
- Recognize authentication flow vulnerabilities (reset code strength, rate limiting)
- Point out secure token storage guidance missing in design
- Assess token lifecycle management (revocation, expiration)
- Connect biometric flow to token security implications

#### Anti-patterns
- Generic authentication checklist without analyzing specific design choices
- Miss cryptographic weaknesses (MD5)
- Focus only on password security while ignoring PIN vulnerabilities
- Overlook password reset attack surface
- Fail to identify IDOR in account access

---

### T06: Real-Time Collaboration Platform

**Difficulty**: Medium
**Category**: Input Validation & Attack Defense, Data Protection

#### Input

```markdown
# Real-Time Collaboration Platform Design

## Overview
Google Docs-like collaborative editing platform with real-time synchronization.

## Architecture
- Frontend: React with WebSocket client
- WebSocket Server: Socket.io (Node.js)
- Database: MongoDB for documents
- Cache: Redis for active sessions

## Authentication and Connection
Users authenticate via standard OAuth2 flow, receive JWT access token. When opening document, frontend establishes WebSocket connection with JWT in connection handshake query parameter: `ws://api.example.com/socket?token={jwt}`

WebSocket server validates JWT and establishes persistent connection.

## Document Access Control
Documents have visibility settings:
- Private: Only creator can access
- Team: Organization members can access
- Public: Anyone with link can access

Access check on WebSocket connection: Server extracts documentId from first message, queries MongoDB for document visibility, and verifies user has access based on orgId in JWT.

## Real-Time Editing
Clients send text operations via WebSocket messages:
```json
{
  "type": "edit",
  "documentId": "abc123",
  "operation": {
    "index": 42,
    "delete": 5,
    "insert": "new text"
  }
}
```

Server applies operation to in-memory document state (Redis), broadcasts to all connected clients for that document, and persists to MongoDB every 5 seconds.

## Content Rendering
Document content rendered as HTML on frontend. User-generated content includes formatting tags (bold, italic, links). Server stores content as HTML fragments in MongoDB.

When sharing document publicly, content served via GET /api/documents/{id}/content endpoint with Content-Type: text/html.

## Comment Feature
Users can add comments to document sections. Comments stored in separate collection with documentId reference. Comment text supports @mentions that notify mentioned users.

Mention format: `@username` parsed from comment text, username looked up in users collection, notification sent if user exists.

## Document History
Full edit history maintained with timestamps and userId. History accessible to document owner via GET /api/documents/{id}/history endpoint.
```

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T06-C1 | XSS in Content Rendering | Identifies stored XSS vulnerability from unescaped HTML content with specific attack scenario and recommends sanitization | Mentions XSS risk without specific attack vector | Does not identify XSS vulnerability | 1.0 |
| T06-C2 | JWT Exposure in WebSocket URL | Identifies security risk of JWT in query parameter (logged, cached) and recommends header-based authentication | Mentions WebSocket auth without identifying query parameter risk | Does not identify JWT exposure issue | 1.0 |
| T06-C3 | NoSQL Injection in Mentions | Identifies NoSQL injection risk in username lookup from @mention parsing | Mentions input validation without NoSQL injection specifically | Does not identify NoSQL injection | 1.0 |
| T06-C4 | Race Condition in Access Control | Identifies TOCTOU vulnerability where access check at connection time doesn't prevent later unauthorized access after permission change | Mentions access control without race condition | Does not identify timing vulnerability | 1.0 |
| T06-C5 | Data Leakage in History | Identifies privacy risk where edit history exposes all user contributions even after content deletion | Mentions history feature without privacy implications | Does not identify data leakage | 0.5 |

#### Expected Key Behaviors
- Identify XSS vulnerability in HTML content storage and rendering
- Recognize JWT exposure risk in WebSocket URL parameters
- Point out NoSQL injection in user mention parsing
- Identify timing/race condition in access control validation
- Assess privacy implications of persistent edit history
- Connect real-time architecture to security challenges (stateful connections, access control timing)

#### Anti-patterns
- Generic WebSocket security recommendations without analyzing specific design
- Miss XSS vulnerability in content handling
- Focus only on authentication without examining authorization timing
- Overlook injection vulnerabilities in comment features
- Fail to consider privacy aspects of audit trails

---

### T07: API Gateway with Rate Limiting

**Difficulty**: Easy
**Category**: Threat Modeling (STRIDE), Infrastructure/Dependencies/Audit

#### Input

```markdown
# API Gateway Design

## Purpose
Centralized API gateway for microservices. Handles authentication, rate limiting, and request routing.

## Architecture
Kong API Gateway deployed on Kubernetes. Routes traffic to backend services in same cluster.

## Authentication
All requests require API key in X-API-Key header. Keys stored in PostgreSQL database. Key validation on every request:
1. Extract key from header
2. Query database: SELECT * FROM api_keys WHERE key_value = ?
3. If valid, forward request to backend
4. If invalid, return 401

API keys generated as random UUIDs. Never expire unless manually revoked.

## Rate Limiting
Kong rate limiting plugin configured:
- 100 requests per minute per API key
- Counter stored in Redis
- Exceeding limit returns 429 Too Many Requests

## Request Routing
Routes configured based on path prefix:
- /api/users/* → User Service
- /api/products/* → Product Service
- /api/orders/* → Order Service

Backend services trust all requests from gateway. No additional authentication between gateway and services.

## Logging
All requests logged to stdout with format: `{timestamp} {method} {path} {apiKey} {statusCode} {responseTime}`

Logs shipped to Elasticsearch via Fluentd.

## SSL/TLS
Gateway terminates TLS. Internal traffic between gateway and backend services unencrypted.
```

#### Quality Rubric

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T07-C1 | SQL Injection in Key Validation | Identifies SQL injection risk in API key query and recommends parameterized queries | Mentions input validation without SQL injection specifically | Does not identify SQL injection | 1.0 |
| T07-C2 | Internal Traffic Encryption | Identifies lack of encryption for gateway-to-service communication and recommends mutual TLS | Mentions need for encryption generically | Does not identify internal traffic exposure | 1.0 |
| T07-C3 | API Key Management Weaknesses | Identifies risks of non-expiring keys, lack of rotation policy, and recommends key lifecycle management | Mentions one key management issue | Does not identify key management problems | 1.0 |
| T07-C4 | Sensitive Data in Logs | Identifies PII/credential leakage in logs (API keys logged in plaintext) and recommends log sanitization | Mentions logging security without specific data exposure | Does not identify log data leakage | 1.0 |
| T07-C5 | Missing Security Audit | Identifies lack of security event monitoring (key abuse, failed auth attempts, anomaly detection) | Mentions monitoring generically | Does not identify security audit gaps | 0.5 |

#### Expected Key Behaviors
- Apply STRIDE to gateway design (Spoofing via SQL injection, Tampering via unencrypted internal traffic, Repudiation via insufficient audit, Information Disclosure via logs)
- Identify SQL injection in authentication logic
- Recognize internal traffic security gaps
- Point out API key lifecycle management issues
- Identify sensitive data exposure in logs
- Recommend comprehensive security monitoring

#### Anti-patterns
- Generic API gateway best practices without analyzing specific design flaws
- Miss SQL injection vulnerability
- Focus only on external TLS without examining internal traffic
- Overlook logging security and data leakage
- Fail to assess authentication token lifecycle
