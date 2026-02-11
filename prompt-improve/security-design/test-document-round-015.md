# HealthHub Telemedicine Platform - System Design Document

## 1. Overview

### 1.1 Project Purpose
HealthHub is a HIPAA-compliant telemedicine platform connecting patients with healthcare providers for virtual consultations, prescription management, and health monitoring. The platform enables secure video consultations, electronic health record (EHR) integration, and medication prescription workflows.

### 1.2 Key Features
- Patient and provider registration/authentication
- Real-time video consultation with WebRTC
- Electronic prescription management with pharmacy integration
- Secure medical document storage and sharing
- Appointment scheduling with calendar integration
- Health vitals tracking (blood pressure, glucose, heart rate)
- Provider-to-provider consultation referrals

### 1.3 Target Users
- **Patients**: Individuals seeking remote medical consultations
- **Healthcare Providers**: Licensed physicians, nurse practitioners, therapists
- **Pharmacists**: Partner pharmacies receiving prescriptions
- **Care Coordinators**: Administrative staff managing appointments

## 2. Technology Stack

### 2.1 Backend
- **Framework**: Node.js 18 with Express.js 4.18
- **Language**: TypeScript 5.0
- **API Gateway**: Kong 3.2
- **WebRTC Server**: Jitsi Meet (self-hosted)

### 2.2 Database
- **Primary Database**: PostgreSQL 15.2
- **Cache Layer**: Redis 7.0
- **Document Storage**: Amazon S3 (us-east-1)
- **Search Engine**: Elasticsearch 8.6

### 2.3 Infrastructure
- **Cloud Provider**: AWS (us-east-1, us-west-2 multi-region)
- **Container Orchestration**: Kubernetes 1.26
- **CI/CD**: GitHub Actions + ArgoCD
- **Monitoring**: Prometheus + Grafana

### 2.4 Key Libraries
- jsonwebtoken 9.0.0 (JWT authentication)
- bcrypt 5.1.0 (password hashing)
- twilio-video 2.27.0 (video consultation alternative)
- stripe 11.16.0 (payment processing)
- nodemailer 6.9.1 (email notifications)

## 3. Architecture Design

### 3.1 Overall Structure
The platform follows a microservices architecture with the following core services:
- **Auth Service**: User authentication and authorization
- **Consultation Service**: Video session management
- **Prescription Service**: Medication orders and pharmacy integration
- **EHR Service**: Medical records management
- **Notification Service**: Email/SMS alerts
- **Payment Service**: Insurance claims and co-pay processing

### 3.2 Component Responsibilities
- **API Gateway (Kong)**: Routes requests to microservices, applies rate limiting (100 req/min per IP)
- **Auth Service**: Issues JWT tokens with 24-hour expiration, manages user sessions
- **Consultation Service**: Creates WebRTC rooms, records session metadata
- **Prescription Service**: Validates prescription requests, sends to pharmacy API
- **EHR Service**: CRUD operations for medical records, document upload/download
- **Notification Service**: Sends appointment reminders and prescription status updates

### 3.3 Data Flow
1. User authenticates via Auth Service, receives JWT token stored in browser localStorage
2. Frontend includes JWT in Authorization header for all API requests
3. API Gateway validates token signature and routes to appropriate service
4. Services query PostgreSQL for business logic and return JSON responses
5. Medical documents are uploaded directly to S3 with pre-signed URLs

## 4. Data Model

### 4.1 Core Entities

#### User Table
```sql
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL, -- 'patient', 'provider', 'admin'
    created_at TIMESTAMP DEFAULT NOW()
);
```

#### Provider Table
```sql
CREATE TABLE providers (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    license_number VARCHAR(100) NOT NULL,
    specialization VARCHAR(100),
    verified BOOLEAN DEFAULT FALSE
);
```

#### Consultation Table
```sql
CREATE TABLE consultations (
    id UUID PRIMARY KEY,
    patient_id UUID REFERENCES users(id),
    provider_id UUID REFERENCES providers(id),
    scheduled_at TIMESTAMP NOT NULL,
    status VARCHAR(50), -- 'scheduled', 'in_progress', 'completed', 'cancelled'
    notes TEXT,
    recording_url VARCHAR(500)
);
```

#### Prescription Table
```sql
CREATE TABLE prescriptions (
    id UUID PRIMARY KEY,
    consultation_id UUID REFERENCES consultations(id),
    patient_id UUID REFERENCES users(id),
    provider_id UUID REFERENCES providers(id),
    medication_name VARCHAR(255) NOT NULL,
    dosage VARCHAR(100),
    quantity INTEGER,
    pharmacy_id VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW()
);
```

#### Medical Document Table
```sql
CREATE TABLE medical_documents (
    id UUID PRIMARY KEY,
    patient_id UUID REFERENCES users(id),
    document_type VARCHAR(100), -- 'lab_result', 'imaging', 'prescription'
    s3_key VARCHAR(500) NOT NULL,
    uploaded_by UUID REFERENCES users(id),
    uploaded_at TIMESTAMP DEFAULT NOW()
);
```

## 5. API Design

### 5.1 Authentication Endpoints

#### POST /api/auth/register
- **Request**: `{ email, password, role, profile_data }`
- **Response**: `{ user_id, email, role }`
- **Password Requirements**: Minimum 6 characters
- **Rate Limit**: 10 requests per hour per IP

#### POST /api/auth/login
- **Request**: `{ email, password }`
- **Response**: `{ token, user: { id, email, role } }`
- **Token Format**: JWT with HS256 signature
- **Token Expiration**: 24 hours

#### POST /api/auth/password-reset
- **Request**: `{ email }`
- **Response**: `{ message: "Reset link sent" }`
- **Reset Token**: Sent via email, no expiration specified

### 5.2 Consultation Endpoints

#### POST /api/consultations
- **Auth Required**: Yes (JWT in Authorization header)
- **Request**: `{ provider_id, scheduled_at, reason }`
- **Response**: `{ consultation_id, webrtc_room_url }`
- **Authorization**: Patients can create, providers and admins can view all

#### GET /api/consultations/:id
- **Auth Required**: Yes
- **Response**: Full consultation details including notes and recording URL
- **Authorization**: Patient and provider of the consultation only

#### PATCH /api/consultations/:id
- **Auth Required**: Yes
- **Request**: `{ status, notes }`
- **Authorization**: Provider only

### 5.3 Prescription Endpoints

#### POST /api/prescriptions
- **Auth Required**: Yes
- **Request**: `{ consultation_id, patient_id, medication_name, dosage, quantity, pharmacy_id }`
- **Response**: `{ prescription_id, status }`
- **Authorization**: Providers only
- **Validation**: Medication name checked against DEA controlled substance list

#### GET /api/prescriptions/patient/:patient_id
- **Auth Required**: Yes
- **Response**: Array of prescription objects
- **Authorization**: Patient themselves or their providers

### 5.4 Medical Document Endpoints

#### POST /api/documents/upload
- **Auth Required**: Yes
- **Request**: Multipart form-data with file
- **Response**: `{ document_id, s3_url }`
- **Validation**: Maximum file size 50MB, allowed types: PDF, JPG, PNG, DICOM

#### GET /api/documents/:id
- **Auth Required**: Yes
- **Response**: Pre-signed S3 URL (valid for 15 minutes)
- **Authorization**: Patient owner or their care team

## 6. Implementation Policies

### 6.1 Error Handling
- All API errors return JSON format: `{ error: { code, message, details } }`
- HTTP status codes follow REST conventions (400 client error, 500 server error)
- Stack traces are included in development environment responses
- Database connection errors trigger automatic retry with exponential backoff

### 6.2 Logging
- Application logs use Winston with JSON format
- Log levels: ERROR, WARN, INFO, DEBUG
- All API requests logged with: timestamp, user_id, endpoint, response_time, status_code
- Sensitive data: passwords are masked, but full request bodies are logged for debugging

### 6.3 Testing
- Unit tests with Jest (>80% coverage target)
- Integration tests for API endpoints with supertest
- Load testing with k6 for 1000 concurrent users
- Penetration testing conducted annually by third-party vendor

### 6.4 Deployment
- Blue-green deployment strategy with Kubernetes
- Database migrations run automatically on deployment via Flyway
- Environment variables managed in Kubernetes ConfigMaps
- Secrets (database passwords, API keys) stored in AWS Secrets Manager
- Database backup: Daily snapshots to S3, 30-day retention

## 7. Non-Functional Requirements

### 7.1 Performance
- API response time: p95 < 500ms
- Video consultation: < 200ms latency for US users
- Database query optimization: all queries < 100ms
- CDN (CloudFlare) for static assets with 90% cache hit rate

### 7.2 Security
- All external communication over HTTPS (TLS 1.2+)
- Database encryption at rest using AWS RDS encryption
- JWT tokens signed with HS256 using 256-bit secret key
- Password policy: minimum 6 characters, no complexity requirements
- Session management: single active session per user (new login invalidates previous token)
- Two-factor authentication (2FA) optional for patients, mandatory for providers

### 7.3 Availability & Scalability
- Target uptime: 99.5% (monthly)
- Multi-region deployment for disaster recovery (active-passive)
- Horizontal pod autoscaling: 2-10 replicas per service based on CPU usage (>70%)
- Database read replicas for query load distribution
- Elasticsearch cluster: 3 nodes with shard replication

### 7.4 Compliance
- HIPAA compliance: audit logs, access controls, encryption requirements
- GDPR compliance: data export API, right-to-deletion endpoints
- SOC 2 Type II audit planned for Q4 2026

## 8. Third-Party Integrations

### 8.1 Pharmacy Integration
- **Provider**: SureScripts
- **Protocol**: REST API over HTTPS
- **Authentication**: API key in custom header `X-SureScripts-Key`
- **Data Format**: NCPDP SCRIPT XML

### 8.2 Payment Processing
- **Provider**: Stripe
- **Integration**: stripe-node SDK
- **Webhook Endpoint**: `/api/webhooks/stripe` (validates signature with webhook secret)
- **Stored Data**: Stripe customer IDs, no raw card data stored

### 8.3 Insurance Verification
- **Provider**: Availity
- **Protocol**: EDI 270/271 transactions
- **Frequency**: Real-time verification before each consultation

### 8.4 EHR Integration
- **Protocol**: HL7 FHIR R4
- **Endpoints**: Patient, Observation, MedicationRequest resources
- **Authentication**: OAuth 2.0 client credentials flow
- **Rate Limits**: 100 requests per minute per tenant
