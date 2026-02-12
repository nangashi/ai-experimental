# Real Estate Property Management Platform - System Design Document

## 1. Overview

### 1.1 Project Purpose
Develop a cloud-based property management platform to streamline rental operations for property management companies and landlords. The platform enables property listings, tenant screening, rent collection, maintenance request tracking, and financial reporting.

### 1.2 Core Features
- Property portfolio management (residential and commercial properties)
- Tenant application and screening workflow
- Online rent payment processing with automated reminders
- Maintenance request submission and contractor coordination
- Lease agreement management with e-signature integration
- Financial reporting and analytics dashboard
- Document repository for lease agreements, inspection reports, and notices

### 1.3 Target Users
- Property managers (managing 50-500 properties per organization)
- Landlords (managing 1-20 properties individually)
- Tenants (viewing account information, submitting requests)
- Contractors (responding to maintenance requests)

### 1.4 Usage Scenarios
- Daily: Tenant submits maintenance request, property manager assigns contractor
- Weekly: Property manager reviews financial reports, generates owner statements
- Monthly: Automated rent payment processing, late fee assessment, tenant communication
- Annually: Lease renewal workflow, property inspection scheduling

## 2. Technology Stack

### 2.1 Core Technologies
- Backend: Java 17 with Spring Boot 3.1
- Frontend: React 18 with TypeScript
- Database: PostgreSQL 15
- Cache: Redis 7.0
- Message Queue: RabbitMQ 3.12

### 2.2 Infrastructure
- Cloud Platform: AWS (ECS Fargate for compute, RDS for PostgreSQL)
- File Storage: AWS S3 for documents and images
- CDN: CloudFront for static assets
- Deployment: Docker containers with CI/CD via GitHub Actions

### 2.3 Third-party Integrations
- Payment Gateway: Stripe API for rent collection
- E-signature: DocuSign API for lease agreements
- Background Check: Checkr API for tenant screening
- Email Service: SendGrid for notifications

## 3. Architecture Design

### 3.1 Overall Architecture
The system follows a layered architecture:
- Presentation Layer: React SPA with responsive UI
- API Layer: RESTful API with Spring Boot
- Business Logic Layer: Service classes implementing domain logic
- Data Access Layer: JPA repositories with custom queries
- Integration Layer: External API clients with retry logic

### 3.2 Core Components
- **PropertyService**: Manages property listings, vacancies, unit details
- **TenantService**: Handles tenant profiles, application workflow, lease assignments
- **PaymentService**: Processes rent payments, late fees, refunds via Stripe
- **MaintenanceService**: Manages maintenance requests, contractor assignments, status tracking
- **ReportingService**: Generates financial reports, occupancy analytics, owner statements
- **NotificationService**: Sends email/SMS notifications for payment reminders, request updates
- **DocumentService**: Manages file uploads, storage in S3, retrieval

### 3.3 Data Flow
1. User authentication via JWT tokens (15-minute expiration, refresh token rotation)
2. API requests routed through API Gateway with rate limiting (100 req/min per user)
3. Business logic execution with transaction management
4. Database queries with JPA, data returned to API layer
5. Response serialization and return to client

## 4. Data Model

### 4.1 Core Entities

**Property**
- id (UUID, primary key)
- address (text)
- property_type (enum: RESIDENTIAL, COMMERCIAL)
- total_units (integer)
- owner_id (FK to User)
- created_at, updated_at (timestamp)

**Unit**
- id (UUID, primary key)
- property_id (FK to Property)
- unit_number (text)
- rent_amount (decimal)
- square_footage (integer)
- status (enum: AVAILABLE, OCCUPIED, MAINTENANCE)
- created_at, updated_at (timestamp)

**Tenant**
- id (UUID, primary key)
- user_id (FK to User)
- unit_id (FK to Unit)
- lease_start_date, lease_end_date (date)
- monthly_rent (decimal)
- deposit_amount (decimal)
- created_at, updated_at (timestamp)

**Payment**
- id (UUID, primary key)
- tenant_id (FK to Tenant)
- amount (decimal)
- payment_date (timestamp)
- status (enum: PENDING, COMPLETED, FAILED)
- stripe_payment_id (text)
- created_at, updated_at (timestamp)

**MaintenanceRequest**
- id (UUID, primary key)
- unit_id (FK to Unit)
- tenant_id (FK to Tenant)
- description (text)
- priority (enum: LOW, MEDIUM, HIGH, EMERGENCY)
- status (enum: SUBMITTED, ASSIGNED, IN_PROGRESS, COMPLETED)
- contractor_id (FK to User, nullable)
- created_at, updated_at (timestamp)

**Document**
- id (UUID, primary key)
- entity_type (enum: LEASE, INSPECTION, NOTICE)
- entity_id (UUID)
- file_name (text)
- s3_key (text)
- file_size (bigint)
- upload_date (timestamp)

### 4.2 Relationships
- Property (1) → (N) Unit
- Unit (1) → (1) Tenant (current lease)
- Tenant (1) → (N) Payment
- Unit (1) → (N) MaintenanceRequest
- All entities have soft delete flags (deleted_at timestamp)

## 5. API Design

### 5.1 Property Management APIs

**GET /api/v1/properties**
- Query parameters: owner_id, property_type, page, size
- Returns paginated list of properties
- Response: `{ properties: [...], total: number, page: number }`

**GET /api/v1/properties/{id}/units**
- Returns list of units for a specific property
- Response: `{ units: [...], vacancy_rate: number }`

**GET /api/v1/properties/{id}/financial-summary**
- Returns financial overview for property (total rent collected, outstanding, expenses)
- Response: `{ total_rent: number, collected: number, outstanding: number, expenses: number }`

### 5.2 Tenant Management APIs

**POST /api/v1/tenants/applications**
- Request: `{ user_id, unit_id, employment_info, references }`
- Triggers background check via Checkr API
- Response: `{ application_id, status: "PENDING" }`

**GET /api/v1/tenants/{id}/payment-history**
- Returns payment history for tenant
- Response: `{ payments: [...], total_paid: number, balance: number }`

### 5.3 Payment APIs

**POST /api/v1/payments/process**
- Request: `{ tenant_id, amount, payment_method_id }`
- Calls Stripe API to process payment
- Response: `{ payment_id, status, transaction_id }`

**POST /api/v1/payments/schedule-autopay**
- Sets up recurring payment for tenant
- Request: `{ tenant_id, payment_method_id, day_of_month }`

### 5.4 Maintenance APIs

**POST /api/v1/maintenance/requests**
- Request: `{ unit_id, description, priority, photos }`
- Creates maintenance request
- Sends notification to property manager

**PATCH /api/v1/maintenance/requests/{id}/assign**
- Request: `{ contractor_id }`
- Assigns contractor to request
- Sends notification to contractor

### 5.5 Reporting APIs

**GET /api/v1/reports/occupancy**
- Query parameters: property_id, start_date, end_date
- Returns occupancy rate over time period

**GET /api/v1/reports/owner-statement**
- Query parameters: owner_id, month, year
- Generates PDF statement with rental income, expenses, net income
- Response: `{ statement_url: string }`

## 6. Implementation Guidelines

### 6.1 Error Handling
- All API endpoints return standardized error responses: `{ error: string, message: string, timestamp: string }`
- Client-side validation for form inputs
- Server-side validation with Bean Validation annotations
- Database constraint violations mapped to appropriate HTTP status codes

### 6.2 Logging
- Structured JSON logging with Logback
- Log levels: ERROR (exceptions), WARN (validation failures), INFO (API requests), DEBUG (internal logic)
- Sensitive data (passwords, payment details) excluded from logs
- Log aggregation via CloudWatch Logs

### 6.3 Testing
- Unit tests for service layer with JUnit 5 and Mockito
- Integration tests for API endpoints with TestContainers
- End-to-end tests for critical workflows (payment processing, tenant application)
- Test coverage target: 80% for service and repository layers

### 6.4 Deployment
- Blue-green deployment strategy via ECS task definitions
- Database migrations managed with Flyway
- Environment-specific configuration via AWS Secrets Manager
- Health check endpoints: `/actuator/health`, `/actuator/ready`

## 7. Non-Functional Requirements

### 7.1 Performance
- Expected load: 500 concurrent users during peak hours (9 AM - 11 AM, 5 PM - 7 PM)
- Average response time target: < 500ms for API requests
- Payment processing should complete within 3 seconds
- File upload support up to 10 MB per document

### 7.2 Security
- TLS 1.3 for all API communication
- JWT-based authentication with short expiration (15 minutes)
- Role-based access control (RBAC): Admin, PropertyManager, Landlord, Tenant, Contractor
- Payment data tokenized via Stripe, no storage of credit card numbers
- Regular security audits and dependency scanning

### 7.3 Availability & Scalability
- Target uptime: 99.5% availability
- Multi-AZ deployment for RDS and ECS services
- Auto-scaling for ECS tasks based on CPU utilization (70% threshold)
- Database backups: Daily automated snapshots retained for 7 days

### 7.4 Data Retention
- Payment records retained for 7 years for tax compliance
- Tenant application data retained for 3 years
- Maintenance request history retained indefinitely
- Deleted tenant data purged after 90 days (soft delete period)
