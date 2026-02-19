# Enterprise Content Management System - System Design Document

## 1. Overview

### Project Purpose
Build a cloud-based document management system for legal and financial enterprises to store, version, and collaborate on sensitive documents. The system supports regulatory compliance requirements (GDPR, SOX, HIPAA-lite) and provides audit trails for document access and modifications.

### Key Features
- Document upload, versioning, and lifecycle management
- Full-text search with metadata tagging
- Role-based access control with department-level isolation
- Workflow automation (approval chains, review cycles)
- External sharing with time-limited access links
- Compliance reporting and audit log export

### Target Users
- Legal firms: Contract management, case files
- Finance teams: Financial statements, regulatory filings
- HR departments: Employee records, compliance documents

## 2. Technology Stack

### Language & Framework
- **Backend**: Java 17 + Spring Boot 3.2
- **Frontend**: React 18 + TypeScript
- **Mobile**: React Native (iOS/Android)

### Database
- **Primary DB**: PostgreSQL 15 (metadata, user accounts, permissions)
- **Document Storage**: AWS S3 (encrypted at rest)
- **Search Engine**: Elasticsearch 8.x
- **Cache**: Redis 7.x (session data, search results)

### Infrastructure
- **Cloud Provider**: AWS
- **Container Orchestration**: Kubernetes (EKS)
- **API Gateway**: AWS API Gateway + Kong
- **CDN**: CloudFront
- **Secrets Management**: AWS Secrets Manager

### Key Libraries
- Spring Security 6.x (authentication/authorization)
- Apache Tika (document parsing)
- JWT library: jjwt 0.11.x
- Encryption: Bouncy Castle 1.70

## 3. Architecture Design

### Overall Structure
```
[Client Apps]
    ↓
[API Gateway / Load Balancer]
    ↓
[Application Layer - Microservices]
    ├─ Auth Service
    ├─ Document Service
    ├─ Search Service
    ├─ Workflow Service
    └─ Audit Service
    ↓
[Data Layer]
    ├─ PostgreSQL (RDS)
    ├─ S3 (Document Storage)
    ├─ Elasticsearch
    └─ Redis
```

### Component Responsibilities

**Auth Service**
- User authentication (email/password, SSO via SAML 2.0)
- JWT token issuance (access token: 1h, refresh token: 7d)
- Session management
- Password reset flow

**Document Service**
- Document CRUD operations
- Version control
- Access permission validation
- S3 upload/download orchestration

**Search Service**
- Full-text indexing via Elasticsearch
- Metadata search
- Access control filtering

**Workflow Service**
- Approval workflow orchestration
- Email notifications

**Audit Service**
- Event logging (document access, modifications, permission changes)
- Compliance report generation

### Data Flow
1. User authenticates → Auth Service issues JWT
2. Client includes JWT in Authorization header
3. API Gateway validates JWT signature
4. Request routed to appropriate service
5. Service validates user permissions against DB
6. Document operations trigger audit events
7. Audit Service writes to dedicated audit log table

## 4. Data Model

### Core Entities

**users**
| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PRIMARY KEY |
| email | VARCHAR(255) | UNIQUE, NOT NULL |
| password_hash | VARCHAR(255) | NOT NULL |
| salt | VARCHAR(64) | NOT NULL |
| role | ENUM('admin', 'manager', 'user') | NOT NULL |
| department_id | UUID | FOREIGN KEY |
| created_at | TIMESTAMP | NOT NULL |
| last_login | TIMESTAMP | NULL |

**documents**
| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PRIMARY KEY |
| title | VARCHAR(500) | NOT NULL |
| s3_key | VARCHAR(1024) | NOT NULL |
| version | INTEGER | NOT NULL |
| owner_id | UUID | FOREIGN KEY → users |
| department_id | UUID | FOREIGN KEY |
| is_deleted | BOOLEAN | DEFAULT FALSE |
| created_at | TIMESTAMP | NOT NULL |
| updated_at | TIMESTAMP | NOT NULL |

**permissions**
| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PRIMARY KEY |
| document_id | UUID | FOREIGN KEY → documents |
| user_id | UUID | FOREIGN KEY → users (nullable) |
| group_id | UUID | FOREIGN KEY → groups (nullable) |
| permission_type | ENUM('read', 'write', 'admin') | NOT NULL |
| granted_at | TIMESTAMP | NOT NULL |

**audit_logs**
| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PRIMARY KEY |
| user_id | UUID | FOREIGN KEY → users |
| document_id | UUID | FOREIGN KEY → documents (nullable) |
| action | VARCHAR(100) | NOT NULL |
| ip_address | VARCHAR(45) | NOT NULL |
| timestamp | TIMESTAMP | NOT NULL |
| details | JSONB | NULL |

### Relationships
- Users belong to departments (1:N)
- Documents belong to departments (1:N)
- Permissions can be user-level or group-level
- Audit logs reference users and documents

## 5. API Design

### Authentication Endpoints

**POST /api/v1/auth/login**
```json
Request:
{
  "email": "user@example.com",
  "password": "plaintext_password"
}

Response:
{
  "access_token": "eyJhbGc...",
  "refresh_token": "eyJhbGc...",
  "expires_in": 3600
}
```

**POST /api/v1/auth/refresh**
```json
Request:
{
  "refresh_token": "eyJhbGc..."
}

Response:
{
  "access_token": "eyJhbGc...",
  "expires_in": 3600
}
```

**POST /api/v1/auth/reset-password**
```json
Request:
{
  "email": "user@example.com"
}

Response:
{
  "message": "Password reset email sent"
}
```

### Document Endpoints

**POST /api/v1/documents**
- Authorization: Bearer token (required)
- Content-Type: multipart/form-data
- Request: file upload + metadata
- Response: document ID

**GET /api/v1/documents/{id}**
- Authorization: Bearer token (required)
- Response: document metadata + S3 presigned URL (valid for 5 minutes)

**PUT /api/v1/documents/{id}**
- Authorization: Bearer token (required)
- Request: updated metadata or new file version
- Response: new version number

**DELETE /api/v1/documents/{id}**
- Authorization: Bearer token (required)
- Soft delete (sets is_deleted flag)

**POST /api/v1/documents/{id}/share**
```json
Request:
{
  "recipient_email": "external@example.com",
  "expiration_hours": 24
}

Response:
{
  "share_link": "https://app.example.com/shared/abc123",
  "expires_at": "2026-02-11T10:00:00Z"
}
```

### Search Endpoints

**GET /api/v1/search?q={query}&department={dept_id}**
- Authorization: Bearer token (required)
- Response: filtered document list (respects user permissions)

### Authorization Model
- JWT contains user ID, role, department ID
- API endpoints validate permissions before operations:
  - `read`: User has read permission OR is in same department
  - `write`: User has write permission OR is document owner
  - `delete`: User has admin permission OR is document owner
  - `admin`: Only users with 'admin' role

## 6. Implementation Guidelines

### Error Handling
- Use Spring's @ControllerAdvice for centralized exception handling
- Return standardized error responses:
```json
{
  "error_code": "UNAUTHORIZED",
  "message": "Invalid credentials",
  "timestamp": "2026-02-10T12:00:00Z"
}
```
- Log all errors to CloudWatch with correlation IDs

### Logging Strategy
- Application logs: JSON format with structured fields
- Audit logs: Separate table with immutable records
- Log levels:
  - INFO: Successful operations, user actions
  - WARN: Rate limit exceeded, failed login attempts
  - ERROR: System errors, failed operations

### Testing Strategy
- Unit tests: 80% coverage target
- Integration tests: API endpoint tests with TestContainers
- Security tests: OWASP ZAP automated scans
- Load tests: JMeter scripts (1000 concurrent users)

### Deployment Strategy
- Blue-green deployment via Kubernetes
- Database migrations: Flyway (versioned SQL scripts)
- Secrets rotation: Monthly via AWS Secrets Manager
- Container images scanned with Trivy before deployment

## 7. Non-Functional Requirements

### Performance Targets
- API response time: P95 < 500ms
- Document upload: Support files up to 100MB
- Search response time: P95 < 1s
- Concurrent users: Support 5000 active sessions

### Security Requirements
- Encryption at rest: AES-256 for S3 objects
- Encryption in transit: TLS 1.3 for all API communications
- Password policy: Minimum 12 characters, complexity requirements
- Session timeout: 30 minutes of inactivity
- Failed login lockout: 5 attempts → 15 minute lockout

### Availability & Scalability
- SLA: 99.9% uptime
- Multi-AZ deployment for RDS and EKS
- Auto-scaling: Scale up when CPU > 70%
- Backup strategy: PostgreSQL daily snapshots, S3 versioning enabled
- Disaster recovery: RTO 4 hours, RPO 1 hour

### Compliance
- GDPR: Support data export and right-to-delete
- SOX: Immutable audit logs with 7-year retention
- Access logs: Retain for 90 days minimum
