# SalesPulse CRM Platform - System Design Document

## 1. Overview

### Purpose
SalesPulse is a multi-tenant SaaS CRM platform designed to help small and medium-sized businesses manage their sales pipeline, customer relationships, and team collaboration. The platform provides features for contact management, deal tracking, email integration, reporting, and workflow automation.

### Background
The target market consists of sales teams ranging from 5 to 200 users per organization. The platform must support thousands of concurrent tenants while maintaining data isolation, performance, and cost efficiency.

### Key Features
- Contact and company management with custom fields
- Sales pipeline and deal tracking with customizable stages
- Email integration (Gmail, Outlook) with automatic activity logging
- Team collaboration with mentions, notes, and file attachments
- Custom reporting and dashboards
- Workflow automation and notifications
- Mobile applications (iOS, Android)
- Third-party integrations via REST API and webhooks

### Target Users
- Sales representatives (data entry, deal management)
- Sales managers (pipeline oversight, reporting)
- System administrators (configuration, user management)
- API consumers (integrations, data sync)

## 2. Technology Stack

### Backend
- **Language**: Node.js 18 with TypeScript 4.9
- **Framework**: Express.js 4.18
- **API**: RESTful API with JWT authentication
- **Task Queue**: Bull 4.10 with Redis

### Frontend
- **Framework**: React 18 with TypeScript
- **State Management**: Redux Toolkit
- **UI Library**: Material-UI 5

### Database
- **Primary Database**: PostgreSQL 15 (multi-tenant schema-per-tenant model)
- **Cache**: Redis 7.0 (session storage, rate limiting, task queue)
- **Search**: Elasticsearch 8.7 (full-text search for contacts, companies, deals)
- **File Storage**: AWS S3 (document attachments, profile images)

### Infrastructure
- **Hosting**: AWS (ECS Fargate for containerized services)
- **Container Orchestration**: AWS ECS
- **Load Balancer**: AWS Application Load Balancer
- **CDN**: CloudFront for static assets
- **Monitoring**: CloudWatch, DataDog

### Key Dependencies
- jsonwebtoken 9.0 (JWT generation and validation)
- bcrypt 5.1 (password hashing)
- nodemailer 6.9 (email sending)
- axios 1.3 (HTTP client for third-party integrations)
- multer 1.4 (file upload handling)

## 3. Architecture Design

### Overall Architecture
The system follows a multi-tier architecture with the following layers:

1. **Presentation Layer**: React SPA served via CloudFront
2. **API Gateway Layer**: Express.js API servers behind ALB
3. **Business Logic Layer**: Service classes for domain logic
4. **Data Access Layer**: Repository pattern with PostgreSQL
5. **Integration Layer**: Background workers for async tasks

### Multi-tenancy Model
- **Schema-per-tenant**: Each organization gets a dedicated PostgreSQL schema
- **Tenant Resolution**: Subdomain-based routing (customer1.salespulse.com)
- **Data Isolation**: Application-level enforcement via tenant context middleware

### Component Diagram
```
[React SPA] --> [CloudFront] --> [ALB] --> [Express API Servers]
                                              |
                                              +--> [PostgreSQL (tenant schemas)]
                                              +--> [Redis (sessions, cache)]
                                              +--> [Elasticsearch (search)]
                                              +--> [S3 (file storage)]
                                              +--> [Bull Workers (background jobs)]
```

### Key Components

#### Authentication Service
Handles user authentication and JWT token generation. Tokens contain user ID, tenant ID, and role information. Token expiration is set to 24 hours.

#### Tenant Context Middleware
Extracts tenant identifier from subdomain and attaches to request context. All database queries are automatically scoped to the tenant schema.

#### File Upload Service
Manages file uploads to S3. Files are stored with tenant-prefixed keys. Upload limits: 10MB per file, 50MB per request.

#### Email Integration Service
Syncs emails from Gmail/Outlook using OAuth2. Stores credentials for background sync jobs.

#### Webhook Service
Allows customers to register webhook endpoints for event notifications (new deal, updated contact, etc.). Webhooks are delivered via background workers.

## 4. Data Model

### Core Entities

#### users
- id (UUID, primary key)
- email (VARCHAR, unique within tenant)
- password_hash (VARCHAR)
- full_name (VARCHAR)
- role (ENUM: admin, manager, user)
- tenant_id (UUID, foreign key)
- created_at, updated_at (TIMESTAMP)

#### contacts
- id (UUID, primary key)
- first_name, last_name (VARCHAR)
- email (VARCHAR)
- phone (VARCHAR)
- company_id (UUID, foreign key)
- owner_id (UUID, foreign key to users)
- custom_fields (JSONB)
- tenant_id (UUID)
- created_at, updated_at (TIMESTAMP)

#### deals
- id (UUID, primary key)
- name (VARCHAR)
- amount (DECIMAL)
- stage (ENUM: lead, qualified, proposal, negotiation, closed_won, closed_lost)
- contact_id (UUID, foreign key)
- owner_id (UUID, foreign key to users)
- expected_close_date (DATE)
- tenant_id (UUID)
- created_at, updated_at (TIMESTAMP)

#### email_credentials
- id (UUID, primary key)
- user_id (UUID, foreign key)
- provider (ENUM: gmail, outlook)
- access_token (TEXT)
- refresh_token (TEXT)
- expires_at (TIMESTAMP)
- tenant_id (UUID)

#### webhooks
- id (UUID, primary key)
- url (VARCHAR)
- events (VARCHAR[], array of event types)
- secret (VARCHAR, for HMAC signature)
- active (BOOLEAN)
- tenant_id (UUID)

### Relationships
- One user belongs to one tenant (multi-tenancy)
- One contact belongs to one company
- One deal belongs to one contact and one owner (user)
- One user can have multiple email credentials
- One tenant can have multiple webhook registrations

## 5. API Design

### Authentication
- **Method**: JWT Bearer tokens in Authorization header
- **Token Payload**: `{ userId, tenantId, role, exp }`
- **Token Storage**: Stored in browser localStorage

### Key Endpoints

#### POST /api/auth/login
Request:
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```
Response:
```json
{
  "token": "eyJhbGc...",
  "user": { "id": "...", "email": "...", "role": "..." }
}
```

#### POST /api/auth/password-reset
Request:
```json
{
  "email": "user@example.com"
}
```
Response:
```json
{
  "message": "Password reset email sent"
}
```
Sends email with reset link containing token valid for 1 hour.

#### GET /api/contacts
Query Parameters: `?page=1&limit=50&search=john`
Response: Paginated list of contacts for authenticated user's tenant

#### POST /api/contacts
Request:
```json
{
  "first_name": "John",
  "last_name": "Doe",
  "email": "john@example.com",
  "company_id": "uuid"
}
```
Response: Created contact object

#### PUT /api/deals/:id
Updates deal information. No ownership verification - any user in the tenant can update any deal.

#### DELETE /api/deals/:id
Deletes a deal. No ownership verification - any user in the tenant can delete any deal.

#### POST /api/webhooks
Request:
```json
{
  "url": "https://customer.com/webhook",
  "events": ["deal.created", "contact.updated"]
}
```
Response: Created webhook object with generated secret

#### POST /api/files/upload
Multipart form upload. Files stored in S3 with public-read ACL.

#### POST /api/integrations/email/connect
Request:
```json
{
  "provider": "gmail",
  "code": "oauth_authorization_code"
}
```
Exchanges OAuth code for access/refresh tokens and stores in database.

## 6. Implementation Guidelines

### Error Handling
- Standard HTTP status codes (400, 401, 403, 404, 500)
- Error responses include message and error code
- Unexpected errors logged to CloudWatch

### Logging
- Structured JSON logs with timestamp, level, message, context
- Log levels: DEBUG, INFO, WARN, ERROR
- User actions logged with user ID and tenant ID

### Testing
- Unit tests for business logic (Jest)
- Integration tests for API endpoints (Supertest)
- E2E tests for critical flows (Cypress)
- Target coverage: 80%

### Deployment
- Blue-green deployment via ECS task definition updates
- Database migrations run manually before deployment
- Environment variables for configuration (DB credentials, API keys)

## 7. Non-functional Requirements

### Performance
- API response time: p95 < 500ms
- Search queries: p95 < 1000ms
- Support 10,000 concurrent users
- Database connection pool: 20 connections per instance

### Security
- HTTPS enforced for all traffic
- Passwords hashed with bcrypt (10 rounds)
- SQL injection prevention via parameterized queries
- XSS prevention via React's automatic escaping

### Availability
- Target uptime: 99.9%
- Auto-scaling: 2-10 ECS tasks based on CPU utilization
- Database backups: Daily automated snapshots
- Redis: Single-node deployment (non-clustered)

### Scalability
- Horizontal scaling of API servers via ECS auto-scaling
- Database: Vertical scaling initially, read replicas for scaling reads
- Elasticsearch: 3-node cluster with 2 replicas per index
- S3: Unlimited scalability

### Compliance
- GDPR: Data export and deletion endpoints
- SOC 2: Audit logging for all data access
